use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::IRCBot::Events;

=begin pod

=head1 NAME

Sourcing::Example::IRCBot::Aggregates::ChannelAggregate - IRC channel aggregate

=head1 DESCRIPTION

The ChannelAggregate manages IRC channel state. It handles:
- User join/part events
- Message tracking
- Topic management
- Channel statistics

This aggregate represents a single IRC channel and tracks all events
that occur within it.

=end pod

aggregation Sourcing::Example::IRCBot::Aggregates::ChannelAggregate {

has Str $.channel is projection-id;

# Channel state
has Str $.topic = '';
has Bool $.is-connected = False;
has Int $.message-count = 0;
has Int $.join-count = 0;

# User tracking
has Str @.users;
has Hash %.user-info{Mu} = {};

=begin pod

=head2 Method apply

Event handlers to rebuild aggregate state from events.

=end pod

multi method apply(ChannelJoined $e) {
    $!is-connected = True;
    $!join-count++;
    @.users.push: $e.user unless @.users.first: * eq $e.user;
    %.user-info{$e.user}<joined-at> = $e.joined-at;
}

multi method apply(ChannelParted $e) {
    @.users = @.users.grep: * ne $e.user;
    %.user-info{$e.user}<parted-at> = $e.parted-at;
    %.user-info{$e.user}<reason> = $e.reason;
    $!is-connected = @.users.elems > 0;
}

multi method apply(ChannelMessage $e) {
    $!message-count++;
    %.user-info{$e.user}<messages> //= 0;
    %.user-info{$e.user}<messages>++;
    %.user-info{$e.user}<last-message-at> = $e.sent-at;
}

multi method apply(ChannelTopicChanged $e) {
    $!topic = $e.new-topic;
}

=begin pod

=head2 Method join-channel

Command to handle a user joining the channel.

=end pod

method join-channel(Str :$user) is command {
    die "User $user already in channel $!channel"
        if @.users.first: * eq $user;

    my $event = ChannelJoined.new:
        :channel($!channel),
        :$user,
        :joined-at(DateTime.now);

    $event.emit: :type(self.WHAT);
}

=begin pod

=head2 Method part-channel

Command to handle a user leaving the channel.

=end pod

method part-channel(Str :$user, Str :$reason = '') is command {
    die "User $user not in channel $!channel"
        unless @.users.first: * eq $user;

    my $event = ChannelParted.new:
        :channel($!channel),
        :$user,
        :$reason,
        :parted-at(DateTime.now);

    $event.emit: :type(self.WHAT);
}

=begin pod

=head2 Method receive-message

Command to process a message received in the channel.

=end pod

method receive-message(Str :$user, Str :$message) is command {
    die "User $user not in channel $!channel"
        unless @.users.first: * eq $user;

    my $event = ChannelMessage.new:
        :channel($!channel),
        :$user,
        :$message,
        :sent-at(DateTime.now);

    $event.emit: :type(self.WHAT);
}

=begin pod

=head2 Method change-topic

Command to change the channel topic.

=end pod

method change-topic(Str :$new-topic, Str :$changed-by) is command {
    my $event = ChannelTopicChanged.new:
        :channel($!channel),
        :new-topic($new-topic),
        :changed-by($changed-by),
        :changed-at(DateTime.now);

    $event.emit: :type(self.WHAT);
}

=begin pod

=head2 Method stats

Returns channel statistics.

=end pod

method stats() {
    {
        channel => $!channel,
        topic => $!topic,
        message-count => $!message-count,
        join-count => $!join-count,
        user-count => @.users.elems,
        users => @.users
    }
}
}