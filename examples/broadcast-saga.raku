#!/usr/bin/env raku
use v6.e.PREVIEW;

=begin pod

=head1 NAME

broadcast-saga.raku - Event-driven IRC broadcast saga with declarative rollback

=head1 SYNOPSIS

    raku -Ilib -Iexamples examples/broadcast-saga.raku

=head1 DESCRIPTION

Broadcasts a message across several channels. The saga is event-driven: each
channel send is its own C<ChannelTargeted> event, which the saga reacts to by
sending the message and declaring its inverse with C<anti-event> (a retraction).
On rollback the framework emits those inverses in reverse order — so aborting a
broadcast retracts exactly the channels that received it, newest first.

The reusable saga, aggregate, and events live under C<examples/Broadcast/> and
are exercised by C<t/23-broadcast.rakutest>; this script is just a demo of them.

=end pod

use Sourcing;
use Sourcing::Plugin::Memory;
use Broadcast::Events;
use Broadcast::ChannelAggregate;
use Broadcast::BroadcastSaga;

Sourcing::Plugin::Memory.use;

# Idiomatic dispatch: rebuild from history, apply live, then persist.
sub dispatch(Str $saga-id, $event) {
    my $s = sourcing BroadcastSaga, :$saga-id;
    $s.apply: $event;
    $*SourcingConfig.emit: $event;
    $s
}

sub counts(@channels) {
    @channels.map({ "$_: {(sourcing ChannelAggregate, :channel($_)).message-count}" }).join(', ')
}

say "=== IRC Broadcast Saga Demo ===\n";

my @channels = <#general #random #announcements>;

# --- Demo 1: a broadcast that goes through ---
say "--- Demo 1: broadcast to every channel ---";
for @channels -> $channel {
    dispatch 'bcast-1',
        ChannelTargeted.new(:saga-id<bcast-1>, :$channel, :message('Hello everyone!'), :user<alice>);
}
say "state:  ", (sourcing BroadcastSaga, :saga-id<bcast-1>).state;
say "counts: ", counts(@channels);
say "";

# --- Demo 2: a broadcast that is aborted and rolled back ---
say "--- Demo 2: broadcast, then abort (retractions in reverse) ---";
for @channels -> $channel {
    dispatch 'bcast-2',
        ChannelTargeted.new(:saga-id<bcast-2>, :$channel, :message('Ping'), :user<bob>);
}
say "after broadcast — counts: ", counts(@channels);

my $aborted = dispatch 'bcast-2', BroadcastAborted.new(:saga-id<bcast-2>);
say "state:  ", $aborted.state;
say "after abort   — counts: ", counts(@channels), " (each got a retraction)";
say "";

say "=== Demo Complete ===";
