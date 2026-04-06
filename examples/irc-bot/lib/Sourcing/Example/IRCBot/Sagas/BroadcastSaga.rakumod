use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Saga::Events;
use Sourcing::Example::IRCBot::Events;

# Define a minimal ChannelAggregate inline to avoid cross-module compilation issues
# This is used for the sourcing calls within this saga
aggregation SendChannelAggregate {
    has Str $.channel is required;
    has Int $.message-count = 0;
    
    multi method apply(Sourcing::Example::IRCBot::Events::ChannelMessage $e) {
        $!message-count++;
    }
    
    method receive-message(Str :$user, Str :$message) is command {
        my $event = Sourcing::Example::IRCBot::Events::ChannelMessage.new(
            :channel($!channel),
            :$user,
            :$message,
            :sent-at(DateTime.now)
        );
        $event.emit: :type(SendChannelAggregate);
    }
}

=begin pod

=head1 NAME

Sourcing::Example::IRCBot::Sagas::BroadcastSaga - Saga for broadcasting messages

=head1 DESCRIPTION

A saga that orchestrates broadcasting a message from a user to multiple
IRC channels, with automatic rollback if any send fails.

This demonstrates the saga pattern for multi-channel operations with
compensating transactions.

=head1 STATE MACHINE

    started -> broadcasting -> completed
                          \-> failed -> rolled-back

=end pod

saga Sourcing::Example::IRCBot::Sagas::BroadcastSaga {

# Saga identity
has Str $.saga-id is projection-id;

# Input data
has Str $.initiator;      # User who initiated the broadcast
has Str $.message;       # The message content

# State tracking
has Str $.status = 'started';  # started, broadcasting, completed, failed, rolled-back
has Int $.channels-sent = 0;
has Int $.channels-failed = 0;
has Str $.failure-reason;

# Track successful sends for potential rollback
has Str @.successful-channels;
has Str @.target-channels;

=begin pod

=head2 Method apply

Event handlers to rebuild saga state from events.

=end pod

multi method apply(Sourcing::Saga::Events::SagaCreated $e) {
    # Initial state - saga created
}

multi method apply(Sourcing::Saga::Events::SagaAggregationBound $e) {
    # Aggregation binding handled by metaclass
}

multi method apply(BroadcastStarted $e) {
    $!initiator = $e.initiator;
    $!message = $e.message;
    $!status = 'started';
}

multi method apply(BroadcastChannelSent $e) {
    $!channels-sent++;
    @!successful-channels.push: $e.channel;
}

multi method apply(BroadcastChannelFailed $e) {
    $!channels-failed++;
    $!failure-reason = $e.reason;
    $!status = 'failed';
}

multi method apply(BroadcastCompleted $e) {
    $!status = 'completed';
}

multi method apply(BroadcastRolledBack $e) {
    $!status = 'rolled-back';
}

=begin pod

=head2 Method start

Initialize and start the broadcast saga.

=head3 Parameters

=item C<Str :$initiator> — User who initiated the broadcast

=item C<Str :$message> — The message to broadcast

=item C<Str :@channels> — Channels to broadcast to

=end pod

method start(Str :$initiator, Str :$message, :@channels) {
    $!initiator = $initiator;
    $!message = $message;
    @!target-channels = @channels;
    $!status = 'broadcasting';
    $!channels-sent = 0;
    $!channels-failed = 0;
    @!successful-channels = ();

    # Initialize saga in event store
    self.start;

    # Start broadcasting
    self.broadcast-to-channels;
}

=begin pod

=head2 Method broadcast-to-channels

Step through each channel and send the message.

=end pod

method broadcast-to-channels() {
    for @!target-channels -> $channel {
        self.send-to-channel: $channel;
    }

    # After all channels, mark as completed
    self.complete-broadcast;
}

=begin pod

=head2 Method send-to-channel

Send message to a single channel.
Register compensation in case a later send fails.

=end pod

method send-to-channel(Str $channel) {
    my $ch-agg = sourcing SendChannelAggregate, :$channel;

    try {
        $ch-agg.receive-message:
            :user($!initiator),
            :message($!message);

        # Track successful send
        @!successful-channels.push: $channel;

        # Register compensation action - send retraction on rollback
        self.undo: -> {
            my $retry-ch = sourcing SendChannelAggregate, :$channel;
            $retry-ch.receive-message:
                :user("bot"),
                :message("[Retracted] $!message");
        };

        # Emit success event
        my $event = BroadcastChannelSent.new:
            :saga-id($!saga-id),
            :$channel,
            :sent-at(DateTime.now);

        $event.emit: :type(self.WHAT);

        $!channels-sent++;
    }
    CATCH {
        default {
            my $e = $_;
            # Send failed - mark failure and trigger rollback
            my $fail-event = BroadcastChannelFailed.new:
                :saga-id($!saga-id),
                :$channel,
                :reason($e.message),
                :failed-at(DateTime.now);

            $fail-event.emit: :type(self.WHAT);

            $!channels-failed++;
            $!failure-reason = "Failed to send to $channel: {$e.message}";
            $!status = 'failed';

            # Execute rollback
            self.rollback;
        }
    }
}

=begin pod

=head2 Method complete-broadcast

Mark the broadcast as completed.

=end pod

method complete-broadcast() {
    my $complete-event = BroadcastCompleted.new:
        :saga-id($!saga-id),
        :channels-sent($!channels-sent),
        :channels-failed($!channels-failed),
        :completed-at(DateTime.now);

    $complete-event.emit: :type(self.WHAT);

    $!status = 'completed';
}

=begin pod

=head2 Method rollback

Compensate for successful sends by sending retraction messages.

=end pod

method rollback() {
    # Call parent rollback (executes all undo blocks)
    callsame;

    # Emit rollback event
    my $rollback-event = BroadcastRolledBack.new:
        :saga-id($!saga-id),
        :successful-sends($!channels-sent),
        :reason($!failure-reason // "Broadcast cancelled"),
        :rolled-back-at(DateTime.now);

    $rollback-event.emit: :type(self.WHAT);

    $!status = 'rolled-back';
}

=begin pod

=head2 Method timeout

Timeout handler - if broadcast takes too long, fail gracefully.

=end pod

method timeout() {
    $!failure-reason = "Broadcast timed out";
    $!status = 'failed';
    self.rollback;
}
}
