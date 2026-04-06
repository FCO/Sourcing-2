use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Example::IRC - IRC bot example demonstrating saga pattern

=head1 SYNOPSIS

    use Sourcing::Example::IRC;
    use Sourcing::Plugin::Memory;
    use Sourcing::Example::IRC::ChannelAggregate;
    use Sourcing::Example::IRC::BroadcastSaga;

    # Set up the event store
    my $store = Sourcing::Plugin::Memory.use;

    # Simulate a user message on #general channel
    my $saga = Sourcing::Example::IRC::BroadcastSaga.new:
        :saga-id("broadcast-{DateTime.now.Int}");

    $saga.start:
        :channel('#general'),
        :user('alice'),
        :message('Hello from the saga!');

    # Check the result
    my $result = sourcing Sourcing::Example::IRC::BroadcastSaga, 
        :saga-id($saga.saga-id);

    say "Broadcast status: {$result.status}";
    say "Channels sent: {$result.channels-sent}";
    say "Failed: {$result.channels-failed}";

=head1 DESCRIPTION

This module provides a simple IRC bot example demonstrating the saga pattern
for broadcasting messages across multiple channels with automatic rollback.

=head1 COMPONENTS

=item B<ChannelAggregate> - Represents an IRC channel, handles message sending
=item B<BroadcastSaga> - Orchestrates broadcast across channels with compensation
=item B<Events> - Domain events for messages, failures, and completions

=head1 SAGA FLOW

    1. User sends message on #general
    2. BroadcastSaga.start() is called
    3. For each channel (except original):
       a. Send message via ChannelAggregate
       b. Register compensation (retraction) for rollback
       c. If send fails, trigger rollback
    4. Send confirmation to original user
    5. Mark as completed

    If any step fails:
       - Execute all compensation actions (send retractions)
       - Mark saga as rolled-back
       - Notify user of failure

=end pod

unit module Sourcing::Example::IRC;

use Sourcing::Example::IRC::Events;
use Sourcing::Example::IRC::ChannelAggregate;
use Sourcing::Example::IRC::BroadcastSaga;

# Export key types
our (
    ChannelAggregate,
    BroadcastSaga,
    ChannelMessageSent,
    ChannelSendFailed,
    BroadcastCompleted,
    BroadcastFailed
) is export;
