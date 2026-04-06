use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::Ecommerce::Events;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::OrderProjection - Order read model projection

=head1 DESCRIPTION

A projection that builds a read-optimized view of an order. This projection
tracks all order events and maintains current order state for fast reads.

=end pod

unit class Sourcing::Example::Ecommerce::OrderProjection is projection;

has Str $.order-id is projection-id;
has Str $.customer-id;
has %.items = {};
has Str $.status = 'created';
has DateTime $.created-at;
has DateTime $.submitted-at;
has DateTime $.cancelled-at;
has DateTime $.completed-at;
has Str $.cancellation-reason;
has Numeric $.total = 0;

=begin pod

=head2 Method apply

Updates the projection based on incoming events.

=end pod

multi method apply(OrderCreated $e) {
    $!order-id = $e.order-id;
    $!customer-id = $e.customer-id;
    $!created-at = $e.created-at // DateTime.now;
    $!items = $e.items;
    $!status = $e.status // 'pending';
    $!total = self.calculate-total;
}

multi method apply(OrderItemAdded $e) {
    %.items{$e.item-id} = {
        quantity => $e.quantity,
        unit-price => $e.unit-price
    };
    $!total = self.calculate-total;
}

multi method apply(OrderSubmitted $e) {
    $!status = 'submitted';
    $!submitted-at = $e.submitted-at // DateTime.now;
}

multi method apply(OrderCancelled $e) {
    $!status = 'cancelled';
    $!cancelled-at = $e.cancelled-at // DateTime.now;
    $!cancellation-reason = $e.reason;
}

multi method apply(OrderCompleted $e) {
    $!status = 'completed';
    $!completed-at = $e.completed-at // DateTime.now;
}

=begin pod

=head2 Method calculate-total

Calculates the total order amount from items.

=end pod

method calculate-total() {
    %.items.values.map({ .<quantity> * .<unit-price> }).sum // 0;
}

=begin pod

=head2 Method to-hash

Returns a hash representation for JSON serialization.

=end pod

method to-hash() {
    {
        order-id => $!order-id,
        customer-id => $!customer-id,
        items => %.items,
        status => $!status,
        total => $!total,
        created-at => $!created-at.epoch,
        submitted-at => $!submitted-at.epoch,
        cancelled-at => $!cancelled-at.epoch,
        completed-at => $!completed-at.epoch,
        cancellation-reason => $!cancellation-reason
    }
}