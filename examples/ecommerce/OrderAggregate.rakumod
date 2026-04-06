use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::Ecommerce::Events;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::OrderAggregate - Order aggregate for e-commerce

=head1 DESCRIPTION

The Order aggregate manages the lifecycle of orders. It handles:
- Creating new orders
- Adding items to orders
- Submitting orders for processing
- Cancelling orders
- Completing orders

The aggregate ensures order consistency and enforces business rules like
only being able to modify orders in the 'pending' state.

=end pod

unit class Sourcing::Example::Ecommerce::OrderAggregate is aggregation;

has Str $.order-id is projection-id;
has Str $.customer-id;
has %.items = {};
has Str $.status = 'created';
has DateTime $.created-at = DateTime.now;
has DateTime $.submitted-at;
has DateTime $.cancelled-at;
has Str $.cancellation-reason;

=begin pod

=head2 Method apply

Handles all order events and updates aggregate state accordingly.

=end pod

multi method apply(OrderCreated $e) {
    $!order-id = $e.order-id;
    $!customer-id = $e.customer-id;
    $!created-at = $e.created-at // DateTime.now;
    $!items = $e.items;
    $!status = $e.status // 'pending';
}

multi method apply(OrderItemAdded $e) {
    die "Cannot add items to order in status: $!status" unless $!status eq 'pending';
    %.items{$e.item-id} = {
        quantity => $e.quantity,
        unit-price => $e.unit-price
    };
}

multi method apply(OrderSubmitted $e) {
    die "Cannot submit order in status: $!status" unless $!status eq 'pending';
    $!status = 'submitted';
    $!submitted-at = $e.submitted-at // DateTime.now;
}

multi method apply(OrderCancelled $e) {
    die "Cannot cancel order in status: $!status" unless $!status eq 'pending' | 'submitted';
    $!status = 'cancelled';
    $!cancelled-at = $e.cancelled-at // DateTime.now;
    $!cancellation-reason = $e.reason;
}

multi method apply(OrderCompleted $e) {
    die "Cannot complete order in status: $!status" unless $!status eq 'submitted';
    $!status = 'completed';
    $!completed-at = $e.completed-at // DateTime.now;
}

=begin pod

=head2 Method total

Calculates the total order amount.

=end pod

method total() {
    %.items.values.map({ .<quantity> * .<unit-price> }).sum // 0;
}

=begin pod

=head2 Method create-order

Command to create a new order.

=end pod

method create-order(Str :$customer-id, :$items) {
    self.order-created(
        :order-id($!order-id),
        :$customer-id,
        :created-at(DateTime.now),
        :%items
    );
}

=begin pod

=head2 Method add-item

Command to add an item to the order.

=end pod

method add-item(Str :$item-id, Int :$quantity, Numeric :$unit-price) {
    die "Order must be in pending status to add items" unless $!status eq 'pending';
    self.order-item-added(
        :$order-id,
        :$item-id,
        :$quantity,
        :$unit-price
    );
}

=begin pod

=head2 Method submit

Command to submit the order for processing.

=end pod

method submit() {
    die "Order must be pending to submit" unless $!status eq 'pending';
    die "Order must have at least one item" unless %.items.elems;
    self.order-submitted(
        :order-id($!order-id),
        :submitted-at(DateTime.now)
    );
}

=begin pod

=head2 Method cancel

Command to cancel the order.

=end pod

method cancel(Str :$reason) {
    die "Cannot cancel order in status: $!status" unless $!status eq 'pending' | 'submitted';
    self.order-cancelled(
        :order-id($!order-id),
        :$reason,
        :cancelled-at(DateTime.now)
    );
}

=begin pod

=head2 Method complete

Command to mark the order as completed.

=end pod

method complete() {
    die "Can only complete submitted orders" unless $!status eq 'submitted';
    self.order-completed(
        :order-id($!order-id),
        :completed-at(DateTime.now)
    );
}