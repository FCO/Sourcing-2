#!/usr/bin/env raku
use v6.d;
use lib '.';
use lib '..';
use Sourcing;
use Sourcing::Plugin::Memory;
use ShoppingCart;

Sourcing::Plugin::Memory.use;

say "=== Shopping Cart Example ===";

my $cart = sourcing Cart, :1cart-id;
say "Initial total: \${$cart.total}";

$cart.add-item: "Raku in Action", 2, 49.99;
$cart.add-item: "Programming Perl", 1, 59.99;
$cart.^update;

say "After adding items: \${$cart.total}";

$cart.checkout;
$cart.^update;
say "Cart checked out: {$cart.checked-out}";

say "\nDone!";