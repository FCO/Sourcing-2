#!/usr/bin/env raku
use v6.e.PREVIEW;

=begin pod

=head1 NAME

broadcast-saga.raku - Event-driven IRC broadcast saga with declarative rollback

=head1 SYNOPSIS

    raku -Ilib examples/broadcast-saga.raku

=head1 DESCRIPTION

Broadcasts a message across several channels. The saga is event-driven: each
channel send is its own C<ChannelTargeted> event, which the saga reacts to by
sending the message and declaring its inverse with C<anti-event> (a retraction).
The framework queues those inverses and, on rollback, emits them in reverse
order — so aborting a broadcast retracts exactly the channels that received it,
newest first, with no manual bookkeeping.

=end pod

use Sourcing;
use Sourcing::Plugin::Memory;

Sourcing::Plugin::Memory.use;

#=====================================================================
# EVENTS
#=====================================================================

# Channel-stream event (what a channel records).
class ChannelMessageSent {
    has Str $.channel;
    has Str $.message;
    has Str $.sender;
}

# Saga-stream trigger events (keyed by saga-id).
class ChannelTargeted {
    has Str $.saga-id;
    has Str $.channel;
    has Str $.message;
    has Str $.user;
}

class BroadcastAborted {
    has Str $.saga-id;
}

#=====================================================================
# CHANNEL AGGREGATE
#=====================================================================

aggregation ChannelAggregate {
    has Str $.channel is projection-id;
    has Int $.message-count = 0;
    has Bool $.connected = True;

    multi method apply(ChannelMessageSent $e) { $!message-count++ }

    method send-message(Str :$message, Str :$sender) is command {
        die "Channel $!channel is disconnected" unless $!connected;
        $.channel-message-sent: :$message, :$sender;
    }
}

#=====================================================================
# BROADCAST SAGA
#=====================================================================

saga BroadcastSaga {
    has Str $.saga-id is projection-id;
    has Str $.state = 'idle';

    # Send the message to one channel. Valid while idle or already broadcasting.
    multi method apply(ChannelTargeted (:$channel, :$message, :$user, |))
        is on-state(<idle broadcasting>)
    {
        sourcing(ChannelAggregate, :$channel).send-message: :$message, :sender($user);
        'broadcasting'
    }

    # Abort: rollback emits the queued retractions in reverse order.
    multi method apply(BroadcastAborted $) is on-state('broadcasting') {
        self.rollback;
        'aborted'
    }

    # The inverse of a channel send: post a retraction to the same channel. We use
    # the emit method (not the send-message command) so the compensation bypasses
    # the "is it connected?" guard — it undoes a fact that already happened.
    multi method anti-event(ChannelTargeted (:$channel, :$message, |)) {
        sourcing(ChannelAggregate, :$channel).channel-message-sent:
            :message("[Retracted] $message"), :sender('bot');
    }
}

#=====================================================================
# DRIVER
#=====================================================================

# Idiomatic dispatch: rebuild from history, apply live, then persist.
sub dispatch(Str $saga-id, $event) {
    my $s = sourcing BroadcastSaga, :$saga-id;
    $s.apply: $event;
    $*SourcingConfig.emit: $event;
    $s
}

sub message-counts(@channels) {
    @channels.map({ "$_: {(sourcing ChannelAggregate, :channel($_)).message-count}" }).join(', ')
}

say "=== IRC Broadcast Saga Demo ===\n";

my @channels = <#general #random #announcements>;

# --- Demo 1: a broadcast that goes through ---
say "--- Demo 1: broadcast to every channel ---";
my $s1 = 'bcast-1';
for @channels -> $channel {
    dispatch $s1, ChannelTargeted.new(:saga-id($s1), :$channel, :message('Hello everyone!'), :user<alice>);
}
say "state: ", (sourcing BroadcastSaga, :saga-id($s1)).state;
say "counts: ", message-counts(@channels);
say "";

# --- Demo 2: a broadcast that is aborted and rolled back ---
say "--- Demo 2: broadcast, then abort (retractions in reverse) ---";
my $s2 = 'bcast-2';
dispatch $s2, ChannelTargeted.new(:saga-id($s2), :channel('#general'),       :message('Ping'), :user<bob>);
dispatch $s2, ChannelTargeted.new(:saga-id($s2), :channel('#random'),        :message('Ping'), :user<bob>);
dispatch $s2, ChannelTargeted.new(:saga-id($s2), :channel('#announcements'), :message('Ping'), :user<bob>);
say "after broadcast — counts: ", message-counts(@channels);

my $aborted = dispatch $s2, BroadcastAborted.new(:saga-id($s2));
say "state: ", $aborted.state;
say "after abort   — counts: ", message-counts(@channels), " (each got a retraction)";
say "";

say "=== Demo Complete ===";
