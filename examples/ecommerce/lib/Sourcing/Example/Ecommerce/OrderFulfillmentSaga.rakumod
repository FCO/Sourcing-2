use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Saga::Events;
use Sourcing::Example::Ecommerce::Events;
use Sourcing::Example::Ecommerce::OrderAggregate;
use Sourcing::Example::Ecommerce::InventoryAggregate;
use Sourcing::Example::Ecommerce::PaymentAggregate;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::OrderFulfillmentSaga - Saga for order fulfillment

=head1 DESCRIPTION

A saga that orchestrates the multi-step process of fulfilling an order:
1. Receives submitted order
2. Reserves inventory for each item
3. Initiates and authorizes payment
4. Completes the order or rolls back on failure

This saga demonstrates:
- State machine transitions
- Compensation for rollback
- Timeout handling
- Sending commands to multiple aggregates

=end pod

unit saga Sourcing::Example::Ecommerce::OrderFulfillmentSaga;

has Str $.saga-id is projection-id;
has Str $.order-id;
has Str $.status = 'started';
has Str $.customer-id;
has %.items;
has Rat $.total = 0.0;
has Str $.payment-id;
has Bool $.inventory-reserved = False;
has Bool $.payment-authorized = False;
has Bool $.payment-captured = False;
has Str $.failure-reason;

=begin pod

=head2 Method apply

This saga is driven synchronously by command methods (start-fulfillment and
the timeout handler), so its own event stream only ever contains the saga
infrastructure events. Progress flags and status are updated directly by the
command methods below rather than reconstructed from domain events.

Note we deliberately do NOT declare apply handlers for the domain events
(InventoryReserved, PaymentAuthorized, ...): those belong to the aggregates'
streams, not the saga's, and declaring them here would make AggregationHOW
generate emit methods whose kebab names collide with the boolean progress
accessors (e.g. payment-authorized).

=end pod

multi method apply(Sourcing::Saga::Events::SagaCreated $e) {
    # Initial state - saga created
}

multi method apply(Sourcing::Saga::Events::SagaAggregationBound $e) {
    # Aggregation binding events handled automatically by metaclass
}

=begin pod

=head2 Method start-fulfillment

Starts the fulfillment process for a submitted order.
This is called when an order is submitted.

=end pod

method start-fulfillment(Str :$order-id, Str :$customer-id, :%items, Rat :$total) {
    $!order-id = $order-id;
    $!customer-id = $customer-id;
    %!items = %items;
    $!total = $total;
    $!status = 'processing';

    # Start the process by reserving inventory
    self.reserve-inventory;
}

=begin pod

=head2 Method reserve-inventory

Step 1: Reserve inventory for all items in the order.

=end pod

method reserve-inventory() {
    # Reserve stock for each item. If any reservation throws (e.g. insufficient
    # stock), SagaHOW's exception wrapper calls rollback() — which releases the
    # stock reserved so far — and re-throws, so no manual compensation
    # bookkeeping is needed here.
    for %.items.kv -> $item-id, $item-data {
        my $inventory = sourcing Sourcing::Example::Ecommerce::InventoryAggregate, :$item-id;
        $inventory.reserve: :order-id($!order-id), :quantity($item-data<quantity>);
        $!inventory-reserved = True;
    }

    # Schedule timeout in case payment doesn't complete
    self.timeout-in: 'payment-timeout', :seconds(300);  # 5 minutes

    # Proceed to payment
    self.initiate-payment;
}

=begin pod

=head2 Method initiate-payment

Step 2: Initiate payment for the order.

=end pod

method initiate-payment() {
    $!payment-id = "pay-" ~ $!order-id ~ "-" ~ DateTime.now.posix;

    # Create the payment aggregate and initiate it
    my $payment = sourcing Sourcing::Example::Ecommerce::PaymentAggregate, :payment-id($!payment-id);
    $payment.initiate: :order-id($!order-id), :amount($!total), :method<credit-card>;

    # Proceed to authorization
    self.authorize-payment;
}

=begin pod

=head2 Method authorize-payment

Step 3: Authorize the payment.

=end pod

method authorize-payment() {
    my $payment = sourcing Sourcing::Example::Ecommerce::PaymentAggregate, :payment-id($!payment-id);
    $payment.authorize: :authorization-code("AUTH-" ~ $!payment-id);
    $!payment-authorized = True;
    
    # Proceed to capture
    self.capture-payment;
}

=begin pod

=head2 Method capture-payment

Step 4: Capture the payment.

=end pod

method capture-payment() {
    my $payment = sourcing Sourcing::Example::Ecommerce::PaymentAggregate, :payment-id($!payment-id);
    $payment.capture: :captured-amount($!total);
    $!payment-captured = True;
    
    # Cancel the timeout since we succeeded
    self.cancel-timeout: 'payment-timeout';
    
    # Complete the order
    self.complete-order;
}

=begin pod

=head2 Method complete-order

Step 5: Mark the order as completed.

=end pod

method complete-order() {
    my $order = sourcing Sourcing::Example::Ecommerce::OrderAggregate, :order-id($!order-id);
    $order.complete;
    $!status = 'completed';
}

=begin pod

=head2 Method payment-timeout

Timeout handler - if payment doesn't complete in time, fail the order.

=end pod

method payment-timeout() {
    $!failure-reason = "Payment timeout - order failed to complete within allotted time";
    $!status = 'failed';
    self.rollback;
}

=begin pod

=head2 Method rollback

Compensates for any completed steps when the saga fails.

=end pod

method rollback() {
    # SagaHOW wraps every saga method so that an uncaught exception triggers
    # rollback() and re-throws. As the exception unwinds through each nested
    # saga call, every level's wrapper invokes rollback() again on this same
    # instance, so rollback must be idempotent: mark ourselves rolled-back up
    # front and bail out on re-entry, and only compensate the steps whose flags
    # are still set (clearing each as we go).
    return if $!status eq 'rolled-back';
    $!status = 'rolled-back';

    # Release inventory if it was reserved
    if $!inventory-reserved {
        for %.items.kv -> $item-id, $item-data {
            my $inventory = sourcing Sourcing::Example::Ecommerce::InventoryAggregate, :$item-id;
            $inventory.release: :order-id($!order-id);
        }
        $!inventory-reserved = False;
    }

    # Refund the payment if it was captured
    if $!payment-captured {
        my $payment = sourcing Sourcing::Example::Ecommerce::PaymentAggregate, :payment-id($!payment-id);
        $payment.refund: :refunded-amount($!total), :reason("Order fulfillment failed");
        $!payment-captured = False;
    }

    # Cancel the order if it is still in a cancellable state
    if $!order-id {
        my $order = sourcing Sourcing::Example::Ecommerce::OrderAggregate, :order-id($!order-id);
        $order.cancel: :reason($!failure-reason // "Unknown failure")
            if $order.status eq 'pending' | 'submitted';
    }
}