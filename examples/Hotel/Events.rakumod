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
