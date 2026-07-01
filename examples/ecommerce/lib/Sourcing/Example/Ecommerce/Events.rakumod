use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::Events - Event definitions for e-commerce domain

=head1 DESCRIPTION

Events that drive the e-commerce domain model. These events are used by
aggregations to track state changes and by projections to build read models.

=end pod

# NOTE: these event classes are deliberately NOT wrapped in a `unit module`.
# AggregationHOW derives each auto-generated emit method from the event class's
# short name (e.g. InventoryAdjusted -> inventory-adjusted). Inside a unit
# module the names become fully qualified, which breaks that mapping, so the
# classes live at the top level and are shared via `is export`.

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
    has Rat $.unit-price;
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
    has Rat $.amount;
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
    has Rat $.captured-amount;
    has DateTime $.captured-at;
}

class PaymentFailed is export {
    has Str $.payment-id;
    has Str $.reason;
    has DateTime $.failed-at;
}

class PaymentRefunded is export {
    has Str $.payment-id;
    has Rat $.refunded-amount;
    has Str $.reason;
    has DateTime $.refunded-at;
}
# Saga trigger events (the OrderFulfillmentSaga's own stream, keyed by saga-id).
class FulfillmentRequested is export {
    has Str $.saga-id  is required;
    has Str $.order-id  is required;
    has Str $.item-id   is required;
    has Int $.quantity  is required;
    has Rat $.amount    is required;
}

class FulfillmentCancelled is export {
    has Str $.saga-id is required;
}

class FulfillmentConfirmed is export {
    has Str $.saga-id  is required;
    has Str $.order-id is required;
}
