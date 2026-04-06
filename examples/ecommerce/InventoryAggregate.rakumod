use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::Ecommerce::Events;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::InventoryAggregate - Inventory aggregate for e-commerce

=head1 DESCRIPTION

The Inventory aggregate manages product stock levels. It handles:
- Reserving inventory for orders
- Releasing inventory when orders are cancelled
- Adjusting inventory counts (for restocking, damage, etc.)
- Checking availability

=end pod

unit class Sourcing::Example::Ecommerce::InventoryAggregate is aggregation;

has Str $.item-id is projection-id;
has Int $.available = 0;
has Int $.reserved = 0;
has Int $.total = 0;
has %.reservations = {};  # order-id => quantity

=begin pod

=head2 Method apply

Handles all inventory events and updates aggregate state.

=end pod

multi method apply(InventoryAdjusted $e) {
    $!item-id = $e.item-id;
    $!total += $e.quantity-change;
    $!available = $!total - $!reserved;
}

multi method apply(InventoryReserved $e) {
    die "Insufficient inventory for item $!item-id" 
        if $!available < $e.quantity;
    
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

=head2 Method total-available

Returns the total available (unreserved) inventory.

=end pod

method total-available() {
    $!available;
}

=begin pod

=head2 Method reserve

Command to reserve inventory for an order.

=end pod

method reserve(Str :$order-id, Int :$quantity) {
    die "Insufficient inventory. Available: $!available, Requested: $quantity"
        if $!available < $quantity;
    
    self.inventory-reserved(
        :$order-id,
        :item-id($!item-id),
        :$quantity,
        :reserved-at(DateTime.now)
    );
}

=begin pod

=head2 Method release

Command to release inventory reserved for an order.

=end pod

method release(Str :$order-id) {
    my $quantity = %.reservations{$order-id} // 0;
    die "No reservation found for order $order-id" unless $quantity;
    
    self.inventory-released(
        :$order-id,
        :item-id($!item-id),
        :$quantity,
        :released-at(DateTime.now)
    );
}

=begin pod

=head2 Method adjust

Command to adjust inventory levels.

=end pod

method adjust(Int :$quantity-change, Str :$reason) {
    self.inventory-adjusted(
        :item-id($!item-id),
        :$quantity-change,
        :$reason,
        :adjusted-at(DateTime.now)
    );
}