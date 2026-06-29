use Sourcing;
use Hotel::Events;

aggregation RoomAggregate {
    has Str $.room-id         is projection-id;
    has Str $.room-type;
    has Int $.floor;
    has Rat $.price-per-night;
    has Str $.status              = 'available';
    has Str $.current-booking-id;

    multi method apply(RoomCreated $e) {
        $!room-type        = $e.room-type;
        $!floor            = $e.floor;
        $!price-per-night  = $e.price-per-night;
    }

    multi method apply(RoomReserved $e) {
        $!status             = 'reserved';
        $!current-booking-id = $e.booking-id;
    }

    multi method apply(RoomReleased $e) {
        $!status             = 'available';
        $!current-booking-id = Str;
    }

    multi method apply(RoomCheckedIn $e) {
        $!status = 'occupied';
    }

    multi method apply(RoomCheckedOut $e) {
        $!status             = 'available';
        $!current-booking-id = Str;
    }

    method create(Str :$room-type, Int :$floor, Rat :$price-per-night) {
        $.room-created: :$room-type, :$floor, :$price-per-night;
    }

    method reserve(Str :$booking-id, Str :$guest-name, Str :$check-in, Str :$check-out) is command {
        die "Room $!room-id is not available (status: $!status)" unless $!status eq 'available';
        $.room-reserved:
            :$booking-id, :$guest-name, :$check-in, :$check-out,
            room-type => $!room-type;
    }

    method release(Str :$booking-id, Str :$reason = 'Cancelled') is command {
        die "Room $!room-id is not reserved by booking $booking-id"
            unless ($!current-booking-id // '') eq $booking-id;
        $.room-released: :$booking-id, :$reason, room-type => $!room-type;
    }

    method check-in(Str :$booking-id) is command {
        die "Room $!room-id is not reserved" unless $!status eq 'reserved';
        $.room-checked-in:
            :$booking-id,
            actual-check-in => DateTime.now,
            room-type       => $!room-type;
    }

    method check-out(Str :$booking-id) is command {
        die "Room $!room-id is not occupied" unless $!status eq 'occupied';
        $.room-checked-out:
            :$booking-id,
            actual-check-out => DateTime.now,
            room-type        => $!room-type;
    }
}
