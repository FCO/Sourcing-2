use Sourcing;
use Hotel::Events;
use Hotel::RoomAggregate;
use Hotel::BookingAggregate;

# BookingSaga orchestrates the hotel reservation lifecycle, fully event-driven:
# it reacts to events through `apply` handlers, sourcing the Room and Booking
# aggregates and issuing their commands. Each handler destructures the ids it
# needs straight out of the event signature, so the saga keeps no domain state of
# its own — only its state machine.
#
# The state machine is real, not decorative: every apply returns the next state
# (SagaHOW sets `$.state` from it) and is tagged with `is on-state(...)`, which is
# a dispatch key. Several apply candidates may handle the same event in different
# states, and the saga picks the one matching the current state. An event that
# matches no candidate for the current state is a no-op — duplicate or late events
# are simply dropped (see the on-state('confirmed') PaymentReceived below).
#
#   pending          --BookingRequested--> awaiting-payment   (reserve room + open booking)
#   awaiting-payment --PaymentReceived---> confirmed          (confirm booking)
#   confirmed        --GuestArrived------> occupied           (check the room in)
#   occupied         --GuestDeparted-----> completed          (check the room out)
#   awaiting-payment --PaymentTimedOut---> cancelled          (rollback)
#
# Compensation is declarative: `anti-event(BookingRequested)` builds the inverse
# of what BookingRequested does (release the room, cancel the booking). The
# framework queues those inverses on every apply and emits them in reverse order
# on rollback — no manual `self.undo`, no hand-written `rollback`.
#
# If any step throws an unexpected exception, SagaHOW's exception wrapper calls
# rollback() (replaying the queued anti-events) and transitions state to 'failed'.

saga BookingSaga {
    has Str $.saga-id is projection-id;
    has Str $.state   = 'pending';

    # A booking request reserves the room and opens the booking record.
    multi method apply(
        BookingRequested (:$room-id, :$booking-id, :$guest-name, :$check-in, :$check-out, :$price-per-night, |)
    ) is on-state('pending') {
        my $room = sourcing RoomAggregate, :$room-id;
        $room.reserve: :$booking-id, :$guest-name, :$check-in, :$check-out;

        my $booking = sourcing BookingAggregate, :$booking-id;
        $booking.create: :$guest-name, :$room-id, :$check-in, :$check-out, :$price-per-night;

        'awaiting-payment'
    }

    # Payment confirmed: confirm the booking.
    multi method apply(PaymentReceived (:$booking-id, |)) is on-state('awaiting-payment') {
        sourcing(BookingAggregate, :$booking-id).confirm;
        'confirmed'
    }

    # A second candidate for the SAME event in a later state: a duplicate or late
    # payment after the booking is already confirmed is a deliberate no-op. The
    # state-aware dispatch picks this over rolling anything back.
    multi method apply(PaymentReceived $) is on-state('confirmed') { }

    # Guest arrives: mark the room occupied.
    multi method apply(GuestArrived (:$room-id, :$booking-id, |)) is on-state('confirmed') {
        sourcing(RoomAggregate, :$room-id).check-in: :$booking-id;
        'occupied'
    }

    # Guest leaves: free the room again.
    multi method apply(GuestDeparted (:$room-id, :$booking-id, |)) is on-state('occupied') {
        sourcing(RoomAggregate, :$room-id).check-out: :$booking-id;
        'completed'
    }

    # Payment did not arrive in time: roll back. rollback() emits the queued
    # anti-events (room released + booking cancelled) in reverse order.
    multi method apply(PaymentTimedOut $) is on-state('awaiting-payment') {
        self.rollback;
        'cancelled'
    }

    # Declarative compensation for a booking request: release the room and cancel
    # the booking. We source the room to read its required `room-type`; the emit
    # methods fill the projection-ids (room-id, booking-id). Two inverse events
    # are produced — each is queued and replayed in reverse on rollback. We call
    # the emit methods (room-released / booking-cancelled), not the commands, on
    # purpose: a compensation undoes a fact that already happened and must bypass
    # the forward command validation. No manual self.undo is needed.
    multi method anti-event(BookingRequested (:$room-id, :$booking-id, |)) {
        my $room = sourcing RoomAggregate, :$room-id;
        $room.room-released:
            :$booking-id, :reason('Booking saga cancelled'),
            room-type => $room.room-type;

        sourcing(BookingAggregate, :$booking-id).booking-cancelled:
            :reason('Booking saga cancelled');
    }
}
