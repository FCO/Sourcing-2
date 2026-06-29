use Sourcing;
use Hotel::Events;

aggregation BookingAggregate {
    has Str $.booking-id is projection-id;
    has Str $.guest-name;
    has Str $.room-id;
    has Str $.check-in;
    has Str $.check-out;
    has Rat $.total-price;
    has Str $.status = 'pending';
    has Str $.cancellation-reason;

    multi method apply(BookingCreated $e) {
        $!guest-name  = $e.guest-name;
        $!room-id     = $e.room-id;
        $!check-in    = $e.check-in;
        $!check-out   = $e.check-out;
        $!total-price = $e.total-price;
        $!status      = 'pending';
    }

    multi method apply(BookingConfirmed $e) {
        $!status = 'confirmed';
    }

    multi method apply(RoomCheckedIn $e) {
        $!status = 'checked-in';
    }

    multi method apply(RoomCheckedOut $e) {
        $!status = 'checked-out';
    }

    multi method apply(BookingCancelled $e) {
        $!status               = 'cancelled';
        $!cancellation-reason  = $e.reason;
    }

    method create(Str :$guest-name, Str :$room-id, Str :$check-in, Str :$check-out, Rat :$price-per-night) is command {
        my $nights = Date.new($check-out) - Date.new($check-in);
        my $total-price = $nights * $price-per-night;
        $.booking-created: :$guest-name, :$room-id, :$check-in, :$check-out, :$total-price;
    }

    method confirm is command {
        die "Booking must be pending to confirm (status: $!status)" unless $!status eq 'pending';
        $.booking-confirmed;
    }

    method cancel(Str :$reason = 'Cancelled by guest') is command {
        die "Cannot cancel booking in status: $!status"
            if $!status eq 'checked-in' | 'checked-out';
        $.booking-cancelled: :$reason;
    }
}
