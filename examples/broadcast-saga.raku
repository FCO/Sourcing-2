#!/usr/bin/env raku
use v6.e.PREVIEW;
use lib '..';

=begin pod

=head1 NAME

broadcast-saga.raku - Demonstration of IRC broadcast saga

=head1 SYNOPSIS

    raku examples/broadcast-saga.raku

=head1 DESCRIPTION

Demonstrates the BroadcastSaga pattern for an IRC bot that broadcasts
messages across multiple channels with automatic rollback on failure.

This example defines everything inline for simplicity, matching the pattern
used in the test suite.

=end pod

use Sourcing;
use Sourcing::Plugin::Memory;
use Sourcing::Saga::Events;

say "=== IRC Broadcast Saga Demo ===\n";

# Initialize the event store
Sourcing::Plugin::Memory.use;

#=====================================================================
# EVENT DEFINITIONS
#=====================================================================

class ChannelMessageSent {
    has Str $.saga-id;
    has Str $.channel;
    has Str $.message;
    has Str $.sender;
    has DateTime $.sent-at;
}

class ChannelSendFailed {
    has Str $.saga-id;
    has Str $.channel;
    has Str $.reason;
    has DateTime $.failed-at;
}

class UserMessageSent {
    has Str $.saga-id;
    has Str $.user;
    has Str $.channel;
    has DateTime $.sent-at;
}

class BroadcastCompleted {
    has Str $.saga-id;
    has Int $.channels-broadcast;
    has DateTime $.completed-at;
}

class BroadcastFailed {
    has Str $.saga-id;
    has Str $.reason;
    has Int $.successful-sends;
    has Int $.failed-sends;
    has DateTime $.failed-at;
}

class BroadcastRolledBack {
    has Str $.saga-id;
    has Int $.successful-sends;
    has Str $.failed-channel;
    has DateTime $.rolled-back-at;
}

class ChannelConnected {
    has Str $.channel;
    has DateTime $.connected-at = DateTime.now;
}

class ChannelDisconnected {
    has Str $.channel;
    has Str $.reason = '';
    has DateTime $.disconnected-at = DateTime.now;
}

#=====================================================================
# CHANNEL AGGREGATE
#=====================================================================

aggregation ChannelAggregate {
    has Str $.channel is projection-id;
    has Int $.message-count = 0;
    has Bool $.is-connected = True;

    multi method apply(ChannelMessageSent $e) {
        $!message-count++;
    }

    multi method apply(ChannelDisconnected $e) {
        $!is-connected = False;
    }

    multi method apply(ChannelConnected $e) {
        $!is-connected = True;
    }

    method start() {
        self.channel-connected: :channel($!channel);
    }

    method send-message(Str :$message, Str :$sender) {
        die "Cannot send to disconnected channel $!channel"
            unless $!is-connected;

        self.channel-message-sent:
            :channel($!channel),
            :$message,
            :$sender,
            :sent-at(DateTime.now);
    }

    method send-retraction(Str :$original-message, Str :$reason) {
        my $retraction-msg = "[Retracted: $reason] Original: $original-message";
        self.send-message: :message($retraction-msg), :sender("bot");
    }

    method disconnect(Str :$reason = '') {
        self.channel-disconnected: :$!channel, :$reason;
    }
}

#=====================================================================
# BROADCAST SAGA
#=====================================================================

saga BroadcastSaga {
    has Str $.saga-id is projection-id;
    has Str $.original-channel;
    has Str $.user;
    has Str $.message;
    has Str $.status = 'started';
    has Int $.channels-sent = 0;
    has Int $.channels-failed = 0;
    has Int $.successful-sends = 0;
    has Str $.failure-reason;

    # Track successful channels for rollback
    has Str @.successful-channels;

    # Connected channels (in real bot, this would come from bot state)
    has @.connected-channels = <#general #random #announcements>;

    # Event handlers
    multi method apply(Sourcing::Saga::Events::SagaCreated $e) { }

    multi method apply(BroadcastRolledBack $e) {
        $!status = 'rolled-back';
    }

    multi method apply(BroadcastCompleted $e) {
        $!status = 'completed';
    }

    multi method apply(BroadcastFailed $e) {
        $!status = 'failed';
        $!failure-reason = $e.reason;
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

    multi method apply(UserMessageSent $e) { }

    =begin pod

    =head2 start

    Initialize and begin the broadcast saga.

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

        # Start broadcasting to other channels
        self.broadcast-to-channels;
    }

    =begin pod

    =head2 broadcast-to-channels

    Orchestrate sending to all channels.

    =end pod

    method broadcast-to-channels() {
        my @channels = @.connected-channels.grep: * ne $!original-channel;

        for @channels -> $ch {
            self.send-to-channel: $ch;
        }

        # Send confirmation to original user
        self.send-user-confirmation;
    }

    =begin pod

    =head2 send-to-channel

    Send to a single channel. Register compensation for rollback.

    =end pod

    method send-to-channel(Str $channel) {
        my $ch-agg = sourcing ChannelAggregate, :$channel;

        try {
            $ch-agg.send-message: :message($!message), :sender($!user);

            # Track success
            @!successful-channels.push: $channel;
            $!channels-sent++;

            # Register compensation action
            self.undo: -> {
                my $retry-ch = sourcing ChannelAggregate, :$channel;
                $retry-ch.send-retraction:
                    :original-message($!message),
                    :reason($!failure-reason // "Broadcast cancelled");
            };
        }
        CATCH {
            default {
                my $e = $_;
                # Send failed - emit failure event and rollback
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
    }

    =begin pod

    =head2 send-user-confirmation

    Send confirmation back to the original user.

    =end pod

    method send-user-confirmation() {
        my $original-ch = sourcing ChannelAggregate, :channel($!original-channel);

        try {
            my $confirmation = "Your message was broadcast to {$!channels-sent} channel(s)";
            $original-ch.send-message: :message("$confirmation - {$!message}"), :sender("bot");

            my $event = UserMessageSent.new:
                :saga-id($!saga-id),
                :user($!user),
                :channel($!original-channel),
                :sent-at(DateTime.now);

            $event.emit: :type(self.WHAT);
        }
        CATCH {
            default {
                my $e = $_;
                note "Warning: Could not confirm to user $!user: {$e.message}";
            }
        }

        # Mark as completed
        my $complete-event = BroadcastCompleted.new:
            :saga-id($!saga-id),
            :channels-broadcast($!channels-sent),
            :completed-at(DateTime.now);

        $complete-event.emit: :type(self.WHAT);
    }

    =begin pod

    =head2 rollback

    Compensate for successful sends by sending retractions.

    =end pod

    method rollback() {
        callsame;  # Execute undo blocks (sends retractions)

        my $rollback-event = BroadcastRolledBack.new:
            :saga-id($!saga-id),
            :successful-sends($!successful-sends),
            :failed-channel($!failure-reason),
            :rolled-back-at(DateTime.now);

        $rollback-event.emit: :type(self.WHAT);
    }
}

#=====================================================================
# DEMO EXECUTION
#=====================================================================

say "Setting up connected channels...";
for <#general #random #announcements> -> $channel {
    my $ch = ChannelAggregate.new: :$channel;
    $ch.start;
    say "  - Connected to $channel";
}
say "";

# --- Demo 1: Successful Broadcast ---
say "--- Demo 1: Successful Broadcast ---";
say "Alice sends 'Hello everyone!' on #general\n";

my $saga-id-1 = "broadcast-{DateTime.now.Int}";
my $saga = BroadcastSaga.new: :saga-id($saga-id-1);

$saga.start:
    :channel('#general'),
    :user('alice'),
    :message('Hello everyone!');

my $result = sourcing BroadcastSaga, :saga-id($saga-id-1);
say "Result: {$result.status}";
say "Channels sent: {$result.channels-sent}";
say "Failed sends: {$result.channels-failed}";
say "";

say "Channel message counts:";
for <#general #random #announcements> -> $channel {
    my $ch = sourcing ChannelAggregate, :$channel;
    say "  - $channel: {$ch.message-count} messages";
}
say "";

# --- Demo 2: Broadcast with Failure ---
say "--- Demo 2: Broadcast with Failure & Rollback ---";
say "Bob sends 'Important announcement!' on #random\n";

my $saga-id-2 = "broadcast-{DateTime.now.Int}";
my $saga-2 = BroadcastSaga.new: :saga-id($saga-id-2);

# Disconnect #announcements to simulate failure
my $disc = ChannelAggregate.new: :channel('#announcements');
$disc.disconnect: :reason("Network error");

$saga-2.start:
    :channel('#random'),
    :user('bob'),
    :message('Important announcement!');

my $result-2 = sourcing BroadcastSaga, :saga-id($saga-id-2);
say "Result: {$result-2.status}";
say "Channels sent: {$result-2.channels-sent}";
say "Failed sends: {$result-2.channels-failed}";
say "Failure reason: {$result-2.failure-reason // 'N/A'}";
say "";

say "Channel message counts after rollback:";
for <#general #random #announcements> -> $channel {
    my $ch = sourcing ChannelAggregate, :$channel;
    say "  - $channel: {$ch.message-count} messages";
}
say "";

say "Note: Since #announcements was disconnected, the broadcast failed.";
say "The saga rolled back by sending retractions to successful channels.";
say "";

say "=== Demo Complete ===";
