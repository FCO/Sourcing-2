use Sourcing;
use Hotel::Events;

# Read model: counts available / total rooms per room type.
# Because room-type is denormalized into every room event, a single
# projection keyed by room-type can track availability across all rooms.
projection RoomAvailabilityProjection {
    has Str $.room-type       is projection-id;
    has Int $.total-count     = 0;
    has Int $.available-count = 0;
    has Rat $.min-price       = 0.Rat;
    has Rat $.max-price       = 0.Rat;

    multi method apply(RoomCreated $e) is projection-id('room-type') {
        $!total-count++;
        $!available-count++;
        $!min-price = $e.price-per-night
            if !$!min-price || $e.price-per-night < $!min-price;
        $!max-price = $e.price-per-night
            if $e.price-per-night > $!max-price;
    }

    multi method apply(RoomReserved $e) is projection-id('room-type') {
        $!available-count-- if $!available-count > 0;
    }

    multi method apply(RoomReleased $e) is projection-id('room-type') {
        $!available-count++;
    }

    # check-in does not change availability (room was already 'reserved')
    multi method apply(RoomCheckedIn $e) is projection-id('room-type') { }

    multi method apply(RoomCheckedOut $e) is projection-id('room-type') {
        $!available-count++;
    }
}
