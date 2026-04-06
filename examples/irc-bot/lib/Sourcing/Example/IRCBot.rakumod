use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Example::IRCBot - IRC bot example demonstrating Sourcing concepts

=head1 SYNOPSIS

use Sourcing::Example::IRCBot;
use Sourcing::Plugin::Memory;
    
# Set up the event store
my $store = Sourcing::Plugin::Memory.new;
$store.use;
    
# Create and use aggregates
my $channel = Sourcing::Example::IRCBot::Aggregates::ChannelAggregate.new: :channel("#general");
$channel.join-channel: :user("alice");
$channel.receive-message: :user("alice"), :message("Hello world!");
    
# Read via projection
my $stats = sourcing Sourcing::Example::IRCBot::Projections::ChannelStatsProjection, :channel("#general");
say $stats.message-count;  # 1

=head1 DESCRIPTION

This module provides a complete IRC bot domain example showing how to use
Sourcing for event sourcing. It includes:

=item B<Aggregates> - Channel and User aggregates that handle commands
=item B<Projections> - Read-optimized views for karma, aliases, and channel stats
=item B<Sagas> - Broadcast saga for multi-channel messaging
=item B<Events> - Domain events for channels, users, karma, and aliases

=head1 MODULES

=item Sourcing::Example::IRCBot::Events - Event definitions
=item Sourcing::Example::IRCBot::Config - Configuration loader
=item Sourcing::Example::IRCBot::Aggregates::ChannelAggregate - Channel command handling
=item Sourcing::Example::IRCBot::Aggregates::UserAggregate - User command handling
=item Sourcing::Example::IRCBot::Projections::KarmaProjection - Karma read model
=item Sourcing::Example::IRCBot::Projections::AliasProjection - Alias read model
=item Sourcing::Example::IRCBot::Projections::ChannelStatsProjection - Channel stats read model
=item Sourcing::Example::IRCBot::Sagas::BroadcastSaga - Multi-channel broadcast

=head1 CONCEPTS DEMONSTRATED

=item Projection with C<projection>
=item Aggregation with C<aggregation>
=item Saga with C<saga>
=item Command methods with C<is command>
=item Projection IDs with C<is projection-id>
=item Plugins - Memory plugin for event storage

=end pod

unit module Sourcing::Example::IRCBot;

use Sourcing::Example::IRCBot::Events;
use Sourcing::Example::IRCBot::Config;
use Sourcing::Example::IRCBot::Aggregates::ChannelAggregate;
use Sourcing::Example::IRCBot::Aggregates::UserAggregate;
use Sourcing::Example::IRCBot::Projections::KarmaProjection;
use Sourcing::Example::IRCBot::Projections::AliasProjection;
use Sourcing::Example::IRCBot::Projections::ChannelStatsProjection;
use Sourcing::Example::IRCBot::Sagas::BroadcastSaga;

# Export key types
our (
    Config,
    ChannelAggregate,
    UserAggregate,
    KarmaProjection,
    AliasProjection,
    ChannelStatsProjection,
    BroadcastSaga
) is export;
