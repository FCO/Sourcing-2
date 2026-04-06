use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::Ecommerce::Events;

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
- Aggregation binding

=end pod

unit class Sourcing::Example::Ecommerce::OrderFulfillmentSaga is saga;

has Str $.saga-id is projection-id;
has Str $.order-id;
has Str $.status = 'started';
has Str $.customer-id;
has %.items;
has Numeric $.total = 0;
has Str $.payment-id;
has Bool $.inventory-reserved = False;
has Bool $.payment-authorized = False;
has Bool $.payment-captured = False;
has Str $.failure-reason;

# Aggregation bindings
has Sourcing::Example::Ecommerce::OrderAggregate $.order;
has Sourcing::Example::Ecommerce::InventoryAggregate $.inventory;
has Sourcing::Example::Ecommerce::PaymentAggregate $.payment;

=begin pod

=head2 Method apply

Handles events to rebuild saga state from event store.

=end pod

multi method apply(Sourcing::Saga::Events::SagaCreated $e) {
    # Initial state - saga created
}

multi method apply(Sourcing::Saga::Events::SagaAggregationBound $e) {
    # Aggregation binding events handled automatically by metaclass
}

multi method apply(OrderSubmitted $e) {
    $!order-id = $e.order-id;
    $!status = 'processing';
}

multi method apply(InventoryReserved $e) {
    $!inventory-reserved = True;
}

multi method apply(InventoryReleased $e) {
    $!inventory-reserved = False;
}

multi method apply(PaymentInitiated $e) {
    $!payment-id = $e.payment-id;
    $!status = 'payment-processing';
}

multi method apply(PaymentAuthorized $e) {
    $!payment-authorized = True;
}

multi method apply(PaymentCaptured $e) {
    $!payment-captured = True;
    $!status = 'completed';
}

multi method apply(PaymentFailed $e) {
    $!failure-reason = "Payment failed: $e.reason()";
    $!status = 'failed';
}

multi method apply(OrderCancelled $e) {
    $!status = 'cancelled';
}

=begin pod

=head2 Method start-fulfillment

Starts the fulfillment process for a submitted order.
This is called when an order is submitted.

=end pod

method start-fulfillment(Str :$order-id, Str :$customer-id, :%items, Numeric :$total) {
    $!order-id = $order-id;
    $!customer-id = $customer-id;
    %.items = %items;
    $!total = $total;
    $!status = 'processing';
    
    # Bind aggregations for later use
    self.bind-aggregate: 'order', Sourcing::Example::Ecommerce::OrderAggregate, :$order-id;
    
    # Start the process by reserving inventory
    self.reserve-inventory;
}

=begin pod

=head2 Method reserve-inventory

Step 1: Reserve inventory for all items in the order.

=end pod

method reserve-inventory() {
    my $inventory = sourcing Sourcing::Example::Ecommerce::InventoryAggregate, :item-id($_.key) for %.items.keys;
    
    for %.items.kv -> $item-id, $item-data {
        try {
            $inventory.reserve: :order-id($!order-id), :quantity($item-data<quantity>);
            $!inventory-reserved = True;
            
            # Register compensation for rollback
            self.register-compensation: InventoryReleased.new(
                :order-id($!order-id),
                :$item-id,
                quantity => $item-data<quantity>,
                :released-at(DateTime.now)
            );
        }
        catch {
            $!failure-reason = "Failed to reserve inventory for item $item-id: $_";
            $!status = 'failed';
            self.rollback;
            die $!failure-reason;
        }
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
    $!payment-id = "pay-" ~ $!order-id ~ "-" ~ DateTime.now.Int;
    
    # Bind payment aggregate
    self.bind-aggregate: 'payment', Sourcing::Example::Ecommerce::PaymentAggregate, :payment-id($!payment-id);
    
    # Create payment aggregate and initiate
    my $payment = Sourcing::Example::Ecommerce::PaymentAggregate.new:
        :$!payment-id, :order-id($!order-id), :amount($!total), :method<credit-card>;
    
    $payment.initiate: :order-id($!order-id), :amount($!total), :method<credit-card>;
    
    # Register compensation
    self.register-compensation: PaymentRefunded.new(
        :$!payment-id,
        :refunded-amount($!total),
        :reason("Order fulfillment failed")
    );
    
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
    # Release inventory if reserved
    if $!inventory-reserved {
        for %.items.kv -> $item-id, $item-data {
            my $inventory = sourcing Sourcing::Example::Ecommerce::InventoryAggregate, :$item-id;
            $inventory.release: :order-id($!order-id);
        }
    }
    
    # Refund payment if captured
    if $!payment-captured {
        my $payment = sourcing Sourcing::Example::Ecommerce::PaymentAggregate, :payment-id($!payment-id);
        $payment.refund: :refunded-amount($!total), :reason("Order fulfillment failed");
    }
    
    # Cancel the order
    if $!order-id {
        my $order = sourcing Sourcing::Example::Ecommerce::OrderAggregate, :order-id($!order-id);
        $order.cancel: :reason($!failure-reason // "Unknown failure");
    }
    
    $!status = 'rolled-back';
}