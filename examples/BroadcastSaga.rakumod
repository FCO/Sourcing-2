use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::IRC::Events;
use Sourcing::Example::IRC::ChannelAggregate;

=begin pod

=head1 NAME

Sourcing::Example::IRC::BroadcastSaga - Saga for broadcasting messages across channels

=head1 DESCRIPTION

A saga that orchestrates broadcasting a message from a user to all connected
channels, with automatic rollback if any send fails.

=head1 USE CASE

1. User sends a message on a single channel
2. Bot receives the message and starts the BroadcastSaga
3. Saga sends the message to ALL connected channels (except original)
4. Saga sends confirmation back to the original user
5. If any send fails, previously successful sends are compensated with retractions

=head1 STATE MACHINE

    started -> broadcasting -> completed
                        \\-> failed
                        \\-> rolled-back

=end pod

unit class Sourcing::Example::IRC::BroadcastSaga is saga;

# Saga identity
has Str $.saga-id is projection-id;

# Input data
has Str $.original-channel;   # Channel where user sent the message
has Str $.user;              # User who sent the message
has Str $.message;           # The message content

# State tracking
has Str $.status = 'started';    # started, broadcasting, completed, failed, rolled-back
has Int $.channels-sent = 0;
has Int $.channels-failed = 0;
has Int $.successful-sends = 0;

# Track successful sends for potential rollback
has Str @.successful-channels;
has Str $.failure-reason;

=begin pod

=head2 Event handlers

Rebuild saga state from event store.

=end pod

multi method apply(Sourcing::Saga::Events::SagaCreated $e) {
    # Initial state - saga created
}

multi method apply(Sourcing::Saga::Events::SagaAggregationBound $e) {
    # Aggregation binding handled by metaclass
}

multi method apply(BroadcastRequested $e) {
    $!original-channel = $e.channel;
    $!user = $e.user;
    $!message = $e.message;
    $!status = 'started';
}

multi method apply(ChannelMessageSent $e) {
    $!channels-sent++;
    $!successful-sends++;
    @!successful-channels.push: $e.channel unless $e.channel eq $!original-channel;
}

multi method apply(ChannelSendFailed $e) {
    $!channels-failed++;
    $!failure-reason = $e.reason;
    $!status = 'failed';
}

multi method apply(UserMessageSent $e) {
    # Confirmation sent to user
}

multi method apply(BroadcastCompleted $e) {
    $!status = 'completed';
}

multi method apply(BroadcastFailed $e) {
    $!status = 'failed';
}

multi method apply(BroadcastRolledBack $e) {
    $!status = 'rolled-back';
}

=begin pod

=head2 Method start

Initialize and start the broadcast saga.
Creates the saga and begins the broadcast process.

=end pod

method start(Str :$channel, Str :$user, Str :$message) {
    $!original-channel = $channel;
    $!user = $user;
    $!message = $message;
    $!status = 'broadcasting';
    $!channels-sent = 0;
    $!channels-failed = 0;
    @!successful-channels = ();

    # Initialize saga in event store
    self.start;

    # Bind each channel aggregate for later use
    for @.connected-channels -> $ch {
        self.bind-aggregate: "channel-$ch", ChannelAggregate, :channel($ch);
    }

    # Start broadcasting
    self.broadcast-to-channels;
}

=begin pod

=head2 Method connected-channels

Returns the list of channels the bot is connected to.
In a real bot, this would come from the bot's connection state.

=end pod

has @.connected-channels = <#general #random #announcements>;

=begin pod

=head2 Method broadcast-to-channels

Step through each channel and send the message.
This is the main orchestration loop.

=end pod

method broadcast-to-channels() {
    my @channels = @.connected-channels.grep: * ne $!original-channel;

    for @channels -> $channel {
        self.send-to-channel: $channel;
    }

    # After all channels, send confirmation to user
    self.send-user-confirmation;
}

=begin pod

=head2 Method send-to-channel

Send message to a single channel.
Register compensation in case a later send fails.

=end pod

method send-to-channel(Str $channel) {
    my $ch-agg = sourcing ChannelAggregate, :$channel;

    try {
        $ch-agg.send-message: :message($!message), :sender($!user);

        # Track successful send for potential rollback
        @!successful-channels.push: $channel;

        # Register compensation action - send retraction on rollback
        self.undo: -> {
            my $retry-ch = sourcing ChannelAggregate, :$channel;
            $retry-ch.send-retraction:
                :original-message($!message),
                :reason($!failure-reason // "Broadcast cancelled");
        };

        $!channels-sent++;
    }
    catch $e {
        # Send failed - mark failure and trigger rollback
        my $fail-event = ChannelSendFailed.new:
            :saga-id($!saga-id),
            :$channel,
            :reason($e.message),
            :failed-at(DateTime.now);

        $fail-event.emit: :type(self.WHAT);

        $!channels-failed++;
        $!failure-reason = "Failed to send to $channel: {$e.message}";
        $!status = 'failed';

        # Execute rollback - undo all successful sends
        self.rollback;

        return;
    }
}

=begin pod

=head2 Method send-user-confirmation

Send a confirmation message back to the original user.

=end pod

method send-user-confirmation() {
    my $original-ch = sourcing ChannelAggregate, :channel($!original-channel);

    try {
        my $confirmation = "Your message was broadcast to {$!channels-sent} channel(s)";

        $original-ch.send-message:
            :message($confirmation ~ " - {$!message}"),
            :sender("bot");

        my $event = UserMessageSent.new:
            :saga-id($!saga-id),
            :user($!user),
            :channel($!original-channel),
            :sent-at(DateTime.now);

        $event.emit: :type(self.WHAT);
    }
    catch $e {
        # If confirmation fails, log but don't rollback - message was sent
        note "Warning: Could not confirm to user $!user: {$e.message}";
    }

    # Mark broadcast as completed
    my $complete-event = BroadcastCompleted.new:
        :saga-id($!saga-id),
        :channels-broadcast($!channels-sent),
        :completed-at(DateTime.now);

    $complete-event.emit: :type(self.WHAT);
}

=begin pod

=head2 Method rollback

Compensate for successful sends by sending retraction messages.

=end pod

method rollback() {
    # Undo blocks are executed in LIFO order by the base class
    # Each registered undo sends a retraction to the channel

    # Call parent rollback (executes all undo blocks)
    callsame;

    # Emit rollback event
    my $rollback-event = BroadcastRolledBack.new:
        :saga-id($!saga-id),
        :successful-sends($!successful-sends),
        :failed-channel($!failure-reason),
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

# Internal command to start broadcast (emitted to trigger saga)
class BroadcastRequested is export {
    has Str $.saga-id;
    has Str $.channel;
    has Str $.user;
    has Str $.message;
    has DateTime $.requested-at = DateTime.now;
}

class BroadcastRolledBack is export {
    has Str $.saga-id;
    has Int $.successful-sends;
    has Str $.failed-channel;
    has DateTime $.rolled-back-at;
}
