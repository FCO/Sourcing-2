use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::IRCBot::Events;

=begin pod

=head1 NAME

Sourcing::Example::IRCBot::Projections::ChannelStatsProjection - Channel statistics projection

=head1 DESCRIPTION

A read model that tracks statistics for IRC channels including:
- Message counts
- Top users by activity
- Join/part counts
- Topic history

=end pod

projection Sourcing::Example::IRCBot::Projections::ChannelStatsProjection {

has Str $.channel is projection-id;

# Counters
has Int $.message-count = 0;
has Int $.join-count = 0;
has Int $.part-count = 0;

# User statistics: nickname => { messages, joins }
has Hash %.user-stats{Mu} = {};

# Topic tracking
has Str $.current-topic;
has Str $.topic-set-by;
has DateTime $.topic-set-at;

# History - store last 10 messages
has Str @.recent-messages = [];

=begin pod

=head2 Method apply

Apply events to update the channel stats projection.

=end pod

multi method apply(ChannelJoined $e) {
    $!join-count++;
    %.user-stats{$e.user}<joins> //= 0;
    %.user-stats{$e.user}<joins>++;
    %.user-stats{$e.user}<joined-at> = $e.joined-at;
}

multi method apply(ChannelParted $e) {
    $!part-count++;
    %.user-stats{$e.user}<parts> //= 0;
    %.user-stats{$e.user}<parts>++;
    %.user-stats{$e.user}<parted-at> = $e.parted-at;
}

multi method apply(ChannelMessage $e) {
    $!message-count++;
    %.user-stats{$e.user}<messages> //= 0;
    %.user-stats{$e.user}<messages>++;
    %.user-stats{$e.user}<last-message-at> = $e.sent-at;

    # Track recent messages
    @.recent-messages.push: "[$e.sent-at.hh-mm-ss] <$e.user> $e.message";
    @.recent-messages = @.recent-messages.tail(10);
}

multi method apply(ChannelTopicChanged $e) {
    $!current-topic = $e.new-topic;
    $!topic-set-by = $e.changed-by;
    $!topic-set-at = $e.changed-at;
}

=begin pod

=head2 Method top-users

Returns users sorted by message count.

=head3 Parameters

=item C<Int $n> — Number of users to return (default: 5)

=end pod

method top-users(Int $n = 5) {
    %.user-stats
        .map({ $_.key => $_.value<messages> // 0 })
        .sort({ $^b.value <=> $^a.value })
        .head($n)
        .map({ $_.key => $_.value });
}

=begin pod

=head2 Method user-activity

Returns activity summary for a specific user.

=head3 Parameters

=item C<Str $user> — The username to get stats for

=end pod

method user-activity(Str $user) {
    %.user-stats{$user} // {};
}

=begin pod

=head2 Method stats

Returns overall channel statistics.

=end pod

method stats() {
    {
        channel => $!channel,
        message-count => $!message-count,
        join-count => $!join-count,
        part-count => $!part-count,
        topic => $!current-topic,
        topic-set-by => $!topic-set-by,
        active-users => %.user-stats.keys.elems
    }
}
}
