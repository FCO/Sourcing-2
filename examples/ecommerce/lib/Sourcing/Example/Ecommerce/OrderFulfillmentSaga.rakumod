use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Saga::Events;
use Sourcing::Example::Ecommerce::Events;
use Sourcing::Example::Ecommerce::OrderAggregate;
use Sourcing::Example::Ecommerce::InventoryAggregate;
use Sourcing::Example::Ecommerce::PaymentAggregate;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::OrderFulfillmentSaga - Event-driven order fulfillment saga

=head1 DESCRIPTION

Fulfils a submitted order across three aggregates: it reserves inventory, takes
payment, and completes the order. The saga is event-driven — it reacts to a
C<FulfillmentRequested> event, sourcing each aggregate and issuing its commands —
and its compensation is B<declarative>: a single C<anti-event(FulfillmentRequested)>
builds the inverse of the whole fulfilment (release stock, refund payment, cancel
the order). The framework queues those inverses and, on rollback, emits them in
reverse order — no manual bookkeeping.

The fulfilment (reserve + pay) is reversible; the order is left C<'submitted'> so
it can still be cancelled. Completing the order is a separate, final step
(C<FulfillmentConfirmed>) with no inverse. Rollback is driven by an event too: a
C<FulfillmentCancelled> event (e.g. from a cancellation request or a timeout)
transitions the saga and rolls it back.

    pending   --FulfillmentRequested--> fulfilled   (reserve + pay)
    fulfilled --FulfillmentConfirmed--> completed   (complete the order; final)
    fulfilled --FulfillmentCancelled--> cancelled   (rollback: release + refund + cancel)

The payment aggregate is addressed by a deterministic id derived from the order
(C<pay-$order-id>), so both the forward flow and the anti-event can reach it
without extra state on the saga.

=end pod

unit saga Sourcing::Example::Ecommerce::OrderFulfillmentSaga;

has Str $.saga-id is projection-id;
has Str $.state = 'pending';

sub payment-id-for(Str $order-id --> Str) { "pay-$order-id" }

=begin pod

=head2 method apply(FulfillmentRequested)

Reserves stock and takes payment (initiate → authorize → capture). Runs only from
the C<'pending'> state. The order is left C<'submitted'> so the fulfilment stays
reversible.

=end pod

multi method apply(
    FulfillmentRequested (:$order-id, :$item-id, :$quantity, :$amount, |)
) is on-state('pending') {
    sourcing(Sourcing::Example::Ecommerce::InventoryAggregate, :$item-id)
        .reserve: :$order-id, :$quantity;

    my $payment-id = payment-id-for $order-id;
    sourcing(Sourcing::Example::Ecommerce::PaymentAggregate, :$payment-id)
        .initiate: :$order-id, :$amount, :method<credit-card>;
    sourcing(Sourcing::Example::Ecommerce::PaymentAggregate, :$payment-id)
        .authorize: :authorization-code("AUTH-$order-id");
    sourcing(Sourcing::Example::Ecommerce::PaymentAggregate, :$payment-id)
        .capture: :captured-amount($amount);

    'fulfilled'
}

=begin pod

=head2 method apply(FulfillmentConfirmed)

Completes the order — the final, irreversible step. It has no C<anti-event>.

=end pod

multi method apply(FulfillmentConfirmed (:$order-id, |)) is on-state('fulfilled') {
    sourcing(Sourcing::Example::Ecommerce::OrderAggregate, :$order-id).complete;
    'completed'
}

=begin pod

=head2 method apply(FulfillmentCancelled)

Cancels a fulfilled order: C<rollback> emits the queued anti-events (release
stock, refund payment, cancel the order) in reverse order.

=end pod

multi method apply(FulfillmentCancelled $) is on-state('fulfilled') {
    self.rollback;
    'cancelled'
}

=begin pod

=head2 method anti-event(FulfillmentRequested)

The declarative inverse of a fulfilment. Sources each aggregate and calls its
emit method (not its command) — a compensation undoes a fact that already
happened, so it emits the inverse directly and bypasses forward validation. The
aggregates' projection-ids (item-id, payment-id, order-id) are filled by the emit
methods, so only the extra fields are passed.

=end pod

multi method anti-event(
    FulfillmentRequested (:$order-id, :$item-id, :$quantity, :$amount, |)
) {
    sourcing(Sourcing::Example::Ecommerce::InventoryAggregate, :$item-id)
        .inventory-released: :$order-id, :$quantity, :released-at(DateTime.now);

    sourcing(Sourcing::Example::Ecommerce::PaymentAggregate, :payment-id(payment-id-for $order-id))
        .payment-refunded: :refunded-amount($amount), :reason('Order fulfillment cancelled'),
            :refunded-at(DateTime.now);

    sourcing(Sourcing::Example::Ecommerce::OrderAggregate, :$order-id)
        .order-cancelled: :reason('Order fulfillment cancelled'), :cancelled-at(DateTime.now);
}
