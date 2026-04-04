use Sourcing;

class ItemAdded is export {
    has UInt $.cart-id is required;
    has Str $.product-name is required;
    has Int $.quantity is required;
    has Rat $.price is required;
}

class CartCheckedOut is export {
    has UInt $.cart-id is required;
}

aggregation Cart {
    has UInt $.cart-id is required is projection-id;
    has Rat $.total = 0.0;
    has Bool $.checked-out = False;
    has Int @.items;

    multi method apply(ItemAdded $e) {
        $!total += $e.price * $e.quantity;
        @!items.push: @!items.elems + 1;
    }

    multi method apply(CartCheckedOut $e) {
        $!checked-out = True;
    }

    method add-item(Str $name, Int $quantity, Rat $price) {
        die "Cart checked out" if $!checked-out;
        $.item-added: product-name => $name, :$quantity, :$price;
    }

    method checkout {
        die "Cart already checked out" if $!checked-out;
        $.cart-checked-out;
    }
}