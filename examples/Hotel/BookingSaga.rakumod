use Sourcing;
use Hotel::Events;
use Hotel::RoomAggregate;
use Hotel::BookingAggregate;

# BookingSaga orchestrates the hotel reservation lifecycle, fully event-driven:
# it reacts to events through `apply` handlers, sourcing the Room and Booking
# aggregates and issuing their commands. State transitions are returned from each
# `apply` (the saga state machine sets `$.state` from the return value).
#
#   BookingRequested → reserve room + open booking      (state: awaiting-payment)
#   PaymentReceived  → confirm booking                  (state: confirmed)
#   GuestArrived     → mark room occupied               (state: occupied)
#   GuestDeparted    → mark room available again        (state: completed)
#   PaymentTimedOut  → rollback                          (state: cancelled)
#
# Compensation is declarative: `anti-event(BookingRequested)` builds the inverse
# of what BookingRequested does (release the room, cancel the booking). The
# framework queues those inverses on every apply and emits them in reverse order
# on rollback — no manual `self.undo`, no hand-written `rollback`.
#
# If any step throws an unexpected exception, SagaHOW's exception wrapper calls
# rollback() (replaying the queued anti-events) and transitions state to 'failed'.

saga BookingSaga {
    has Str $.saga-id    is projection-id;
    has Str $.state      = 'pending';
    has Str $.room-id;
    has Str $.booking-id;

    # A booking request reserves the room and opens the booking record. The ids
    # are remembered so later steps (payment, check-in/out) can reach the same
    # aggregates after the saga is reconstructed.
    multi method apply(BookingRequested $e) {
        $!room-id    = $e.room-id;
        $!booking-id = $e.booking-id;

        my $room = sourcing RoomAggregate, :room-id($e.room-id);
        $room.reserve:
            :booking-id($e.booking-id), :guest-name($e.guest-name),
            :check-in($e.check-in), :check-out($e.check-out);

        my $booking = sourcing BookingAggregate, :booking-id($e.booking-id);
        $booking.create:
            :guest-name($e.guest-name), :room-id($e.room-id),
            :check-in($e.check-in), :check-out($e.check-out),
            :price-per-night($e.price-per-night);

        'awaiting-payment'
    }

    # Payment confirmed: confirm the booking.
    multi method apply(PaymentReceived $e) {
        sourcing(BookingAggregate, :booking-id($!booking-id)).confirm;
        'confirmed'
    }

    # Guest arrives: mark the room occupied.
    multi method apply(GuestArrived $e) {
        sourcing(RoomAggregate, :room-id($!room-id)).check-in: :booking-id($!booking-id);
        'occupied'
    }

    # Guest leaves: free the room again.
    multi method apply(GuestDeparted $e) {
        sourcing(RoomAggregate, :room-id($!room-id)).check-out: :booking-id($!booking-id);
        'completed'
    }

    # Payment did not arrive in time: roll back. rollback() emits the queued
    # anti-events (room released + booking cancelled) in reverse order.
    multi method apply(PaymentTimedOut $e) {
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
    multi method anti-event(BookingRequested $e) {
        my $room = sourcing RoomAggregate, :room-id($e.room-id);
        $room.room-released:
            :booking-id($e.booking-id), :reason('Booking saga cancelled'),
            room-type => $room.room-type;

        sourcing(BookingAggregate, :booking-id($e.booking-id)).booking-cancelled:
            :reason('Booking saga cancelled');
    }
}
