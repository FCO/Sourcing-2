# Room events
class RoomCreated is export {
    has Str $.room-id         is required;
    has Str $.room-type       is required;
    has Int $.floor           is required;
    has Rat $.price-per-night is required;
}

class RoomReserved is export {
    has Str $.room-id     is required;
    has Str $.room-type   is required;  # denormalized for availability projection
    has Str $.booking-id  is required;
    has Str $.guest-name  is required;
    has Str $.check-in    is required;
    has Str $.check-out   is required;
}

class RoomReleased is export {
    has Str $.room-id    is required;
    has Str $.room-type  is required;
    has Str $.booking-id is required;
    has Str $.reason     is required;
}

class RoomCheckedIn is export {
    has Str      $.room-id          is required;
    has Str      $.room-type        is required;
    has Str      $.booking-id       is required;
    has DateTime $.actual-check-in  is required;
}

class RoomCheckedOut is export {
    has Str      $.room-id           is required;
    has Str      $.room-type         is required;
    has Str      $.booking-id        is required;
    has DateTime $.actual-check-out  is required;
}

# Booking events
class BookingCreated is export {
    has Str $.booking-id  is required;
    has Str $.guest-name  is required;
    has Str $.room-id     is required;
    has Str $.check-in    is required;
    has Str $.check-out   is required;
    has Rat $.total-price is required;
}

class BookingConfirmed is export {
    has Str $.booking-id is required;
}

class BookingCancelled is export {
    has Str $.booking-id is required;
    has Str $.reason     is required;
}

# Saga trigger events — these drive the BookingSaga and live on its own stream,
# keyed by saga-id. The saga reacts to them via `apply` (event-driven), sourcing
# the Room/Booking aggregates and issuing the corresponding commands.
class BookingRequested is export {
    has Str $.saga-id         is required;
    has Str $.room-id         is required;
    has Str $.booking-id      is required;
    has Str $.guest-name      is required;
    has Str $.check-in        is required;
    has Str $.check-out       is required;
    has Rat $.price-per-night is required;
}

# Each trigger event carries the ids its handler needs, so the saga stays
# stateless beyond its own state machine — every apply destructures what it uses.
class PaymentReceived is export {
    has Str $.saga-id    is required;
    has Str $.booking-id is required;
}

class GuestArrived is export {
    has Str $.saga-id    is required;
    has Str $.room-id    is required;
    has Str $.booking-id is required;
}

class GuestDeparted is export {
    has Str $.saga-id    is required;
    has Str $.room-id    is required;
    has Str $.booking-id is required;
}

# Signals that payment did not arrive in time; the saga rolls back on apply. It
# needs no domain ids — the compensation was already queued from BookingRequested.
class PaymentTimedOut is export {
    has Str $.saga-id is required;
}
