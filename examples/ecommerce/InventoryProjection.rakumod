use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::Ecommerce::Events;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::InventoryProjection - Inventory read model projection

=head1 DESCRIPTION

A projection that builds a read-optimized view of inventory. This projection
maintains current stock levels and reservation status for fast queries.

=end pod

unit class Sourcing::Example::Ecommerce::InventoryProjection is projection;

has Str $.item-id is projection-id;
has Int $.available = 0;
has Int $.reserved = 0;
has Int $.total = 0;
has %.reservations = {};  # order-id => quantity
has %.adjustments = [];   # history of adjustments

=begin pod

=head2 Method apply

Updates the projection based on incoming events.

=end pod

multi method apply(InventoryAdjusted $e) {
    $!item-id = $e.item-id;
    $!total += $e.quantity-change;
    $!available = $!total - $!reserved;
    %.adjustments.push: {
        quantity-change => $e.quantity-change,
        reason => $e.reason,
        adjusted-at => $e.adjusted-at // DateTime.now
    };
}

multi method apply(InventoryReserved $e) {
    %.reservations{$e.order-id} //= 0;
    %.reservations{$e.order-id} += $e.quantity;
    $!reserved += $e.quantity;
    $!available = $!total - $!reserved;
}

multi method apply(InventoryReleased $e) {
    my $released = %.reservations{$e.order-id}:delete // 0;
    $!reserved -= $released;
    $!available = $!total - $!reserved;
}

=begin pod

=head2 Method to-hash

Returns a hash representation for JSON serialization.

=end pod

method to-hash() {
    {
        item-id => $!item-id,
        available => $!available,
        reserved => $!reserved,
        total => $!total,
        reservations => %.reservations,
        adjustments => %.adjustments
    }
}