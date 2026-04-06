use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Example::IRCBot::Events - Event definitions for IRC bot

=head1 DESCRIPTION

Events that drive the IRC bot domain model. These events are used by
aggregations to track state changes and by projections to build read models.

Events cover:
=item Channel events (join, part, message)
=item User events (login, logout, karma changes)
=item Command events (alias management)

=end pod

unit module Sourcing::Example::IRCBot::Events;

# ============================================================================
# Channel Events
# ============================================================================

class ChannelJoined is export {
    has Str $.channel;
    has Str $.user;
    has DateTime $.joined-at;
}

class ChannelParted is export {
    has Str $.channel;
    has Str $.user;
    has Str $.reason;
    has DateTime $.parted-at;
}

class ChannelMessage is export {
    has Str $.channel;
    has Str $.user;
    has Str $.message;
    has DateTime $.sent-at;
}

class ChannelTopicChanged is export {
    has Str $.channel;
    has Str $.new-topic;
    has Str $.changed-by;
    has DateTime $.changed-at;
}

# ============================================================================
# User Events
# ============================================================================

class UserLogin is export {
    has Str $.nickname;
    has Str $.ident;
    has Str $.host;
    has DateTime $.login-at;
}

class UserLogout is export {
    has Str $.nickname;
    has Str $.reason;
    has DateTime $.logout-at;
}

class NickChanged is export {
    has Str $.old-nickname;
    has Str $.new-nickname;
    has DateTime $.changed-at;
}

# ============================================================================
# Karma Events
# ============================================================================

class KarmaIncreased is export {
    has Str $.target;
    has Str $.changed-by;
    has Int $.amount;
    has DateTime $.changed-at;
}

class KarmaDecreased is export {
    has Str $.target;
    has Str $.changed-by;
    has Int $.amount;
    has DateTime $.changed-at;
}

class KarmaReset is export {
    has Str $.target;
    has Str $.reset-by;
    has DateTime $.reset-at;
}

# ============================================================================
# Alias Events
# ============================================================================

class AliasSet is export {
    has Str $.alias;
    has Str $.command;
    has Str $.set-by;
    has DateTime $.set-at;
}

class AliasRemoved is export {
    has Str $.alias;
    has Str $.removed-by;
    has DateTime $.removed-at;
}

# ============================================================================
# Broadcast Events (for Sagas)
# ============================================================================

class BroadcastStarted is export {
    has Str $.saga-id;
    has Str $.initiator;
    has Str $.message;
    has DateTime $.started-at;
}

class BroadcastChannelSent is export {
    has Str $.saga-id;
    has Str $.channel;
    has DateTime $.sent-at;
}

class BroadcastChannelFailed is export {
    has Str $.saga-id;
    has Str $.channel;
    has Str $.reason;
    has DateTime $.failed-at;
}

class BroadcastCompleted is export {
    has Str $.saga-id;
    has Int $.channels-sent;
    has Int $.channels-failed;
    has DateTime $.completed-at;
}

class BroadcastRolledBack is export {
    has Str $.saga-id;
    has Int $.successful-sends;
    has Str $.reason;
    has DateTime $.rolled-back-at;
}
