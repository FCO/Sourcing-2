use Sourcing;
use Hotel::Events;
use Hotel::RoomAggregate;
use Hotel::BookingAggregate;

# BookingSaga orchestrates the hotel reservation lifecycle:
#   start-booking  → reserves room + creates booking + schedules timeout
#   payment-received → confirms booking, cancels timeout
#   check-in       → marks room as occupied
#   check-out      → marks room as available again
#
# If payment is not received before the timeout fires, the saga auto-cancels
# and releases the room via the registered undo block.
#
# If any step throws an unexpected exception, SagaHOW's exception wrapper
# automatically calls rollback() and transitions state to 'failed'.

saga BookingSaga {
    has Str $.saga-id        is projection-id;
    has Str $.state          = 'pending';
    has Str $.room-id;
    has Str $.booking-id;
    has Str $.guest-name;
    has Str $.check-in;
    has Str $.check-out;
    has Rat $.price-per-night;

    method start-booking(
        Str :$room-id,
        Str :$booking-id,
        Str :$guest-name,
        Str :$check-in,
        Str :$check-out,
        Rat :$price-per-night,
    ) {
        $!room-id       = $room-id;
        $!booking-id    = $booking-id;
        $!guest-name    = $guest-name;
        $!check-in      = $check-in;
        $!check-out     = $check-out;
        $!price-per-night = $price-per-night;

        # Step 1: reserve the room
        my $room = sourcing RoomAggregate, :$room-id;
        $room.reserve: :$booking-id, :$guest-name, :$check-in, :$check-out;

        # Compensation: release room if anything goes wrong
        self.undo: {
            my $r = sourcing RoomAggregate, :room-id($!room-id);
            $r.release: :booking-id($!booking-id), :reason('Booking saga cancelled');
        };

        # Step 2: create the booking record
        my $booking = sourcing BookingAggregate, :$booking-id;
        $booking.create: :$guest-name, :$room-id, :$check-in, :$check-out, :$price-per-night;

        # Compensation: cancel booking if anything goes wrong
        self.undo: {
            my $b = sourcing BookingAggregate, :booking-id($!booking-id);
            $b.cancel: :reason('Booking saga cancelled');
        };

        # Step 3: schedule auto-cancel timeout (1 hour to receive payment)
        self.timeout-in: 'payment-timeout', :1hours;

        $!state = 'awaiting-payment';
    }

    # Called when payment is confirmed
    method payment-received() {
        die "Saga is not awaiting payment (state: $!state)" unless $!state eq 'awaiting-payment';

        self.cancel-timeout: 'payment-timeout';

        my $booking = sourcing BookingAggregate, :booking-id($!booking-id);
        $booking.confirm;

        $!state = 'confirmed';
    }

    # Called when the guest arrives at the hotel
    method check-in() {
        die "Booking is not confirmed (state: $!state)" unless $!state eq 'confirmed';

        my $room = sourcing RoomAggregate, :room-id($!room-id);
        $room.check-in: :booking-id($!booking-id);

        $!state = 'occupied';
    }

    # Called when the guest leaves
    method check-out() {
        die "Guest is not checked in (state: $!state)" unless $!state eq 'occupied';

        my $room = sourcing RoomAggregate, :room-id($!room-id);
        $room.check-out: :booking-id($!booking-id);

        $!state = 'completed';
    }

    # Fired by the scheduler when the payment timeout expires
    method payment-timeout() {
        self.rollback;
        $!state = 'cancelled';
    }

    method rollback() {
        while @!undo-blocks {
            my $block = @!undo-blocks.pop;
            $block();
        }
        @!undo-blocks = [];
    }
}
