use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::Events - Event definitions for e-commerce domain

=head1 DESCRIPTION

Events that drive the e-commerce domain model. These events are used by
aggregations to track state changes and by projections to build read models.

=end pod

unit module Sourcing::Example::Ecommerce::Events;

# Order Events
class OrderCreated is export {
    has Str $.order-id;
    has Str $.customer-id;
    has DateTime $.created-at;
    has %.items;  # item-id => { qty, unit-price }
    has Str $.status = 'pending';
}

class OrderItemAdded is export {
    has Str $.order-id;
    has Str $.item-id;
    has Int $.quantity;
    has Numeric $.unit-price;
}

class OrderSubmitted is export {
    has Str $.order-id;
    has Str $.status = 'submitted';
    has DateTime $.submitted-at;
}

class OrderCancelled is export {
    has Str $.order-id;
    has Str $.reason;
    has DateTime $.cancelled-at;
}

class OrderCompleted is export {
    has Str $.order-id;
    has DateTime $.completed-at;
}

# Inventory Events
class InventoryReserved is export {
    has Str $.order-id;
    has Str $.item-id;
    has Int $.quantity;
    has DateTime $.reserved-at;
}

class InventoryReleased is export {
    has Str $.order-id;
    has Str $.item-id;
    has Int $.quantity;
    has DateTime $.released-at;
}

class InventoryAdjusted is export {
    has Str $.item-id;
    has Int $.quantity-change;
    has Str $.reason;
    has DateTime $.adjusted-at;
}

# Payment Events
class PaymentInitiated is export {
    has Str $.payment-id;
    has Str $.order-id;
    has Numeric $.amount;
    has Str $.method;  # credit-card, debit, paypal
    has Str $.status = 'pending';
}

class PaymentAuthorized is export {
    has Str $.payment-id;
    has Str $.authorization-code;
    has DateTime $.authorized-at;
}

class PaymentCaptured is export {
    has Str $.payment-id;
    has Numeric $.captured-amount;
    has DateTime $.captured-at;
}

class PaymentFailed is export {
    has Str $.payment-id;
    has Str $.reason;
    has DateTime $.failed-at;
}

class PaymentRefunded is export {
    has Str $.payment-id;
    has Numeric $.refunded-amount;
    has Str $.reason;
    has DateTime $.refunded-at;
}