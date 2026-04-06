use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::IRC::Events;

=begin pod

=head1 NAME

Sourcing::Example::IRC::ChannelAggregate - IRC channel aggregate

=head1 DESCRIPTION

A simple aggregate representing an IRC channel. Handles commands for
sending messages to channels and tracks message history.

This is a simplified aggregate for demonstrating the saga pattern.
In a real IRC bot, this would interact with an actual IRC library.

=end pod

unit class Sourcing::Example::IRC::ChannelAggregate is aggregation;

has Str $.channel is projection-id;
has Str $.topic = '';
has Int $.message-count = 0;
has Bool $.is-connected = True;

# Event handlers to rebuild state
multi method apply(ChannelMessageSent $e) {
    $!message-count++;
}

multi method apply(ChannelConnected $e) {
    $!is-connected = True;
    $!topic = $e.topic // '';
}

multi method apply(ChannelDisconnected $e) {
    $!is-connected = False;
}

multi method apply(ChannelTopicChanged $e) {
    $!topic = $e.topic;
}

multi method apply(ChannelDisconnected $e) {
    $!is-connected = False;
}

=begin pod

=head2 Method disconnect

Command to simulate a channel disconnection.

=end pod

method disconnect(Str :$reason = '') is command {
    my $event = ChannelDisconnected.new:
        :channel($!channel),
        :$reason,
        :disconnected-at(DateTime.now);

    $event.emit: :type(self.WHAT);
}

=begin pod

=head2 Method send-message

Command to send a message to the channel.
Emits ChannelMessageSent event.

=end pod

method send-message(Str :$message, Str :$sender) is command {
    die "Cannot send to disconnected channel $!channel"
        unless $!is-connected;

    my $event = ChannelMessageSent.new:
        :channel($!channel),
        :$message,
        :$sender,
        :sent-at(DateTime.now);

    $event.emit: :type(self.WHAT);
}

=begin pod

=head2 Method send-retraction

Compensation command to send an apology/retraction message.
Used when a partial broadcast needs to be undone.

=end pod

method send-retraction(Str :$original-message, Str :$reason) is command {
    die "Cannot send retraction to disconnected channel $!channel"
        unless $!is-connected;

    # In a real IRC bot, this would send something like:
    # "Sorry, the previous message failed to deliver to all channels: {reason}"
    my $retraction-msg = "[Retracted: $reason] Original: $original-message";

    my $event = ChannelMessageSent.new:
        :channel($!channel),
        :message($retraction-msg),
        :sender("bot"),
        :sent-at(DateTime.now);

    $event.emit: :type(self.WHAT);
}

# Internal events for channel lifecycle
class ChannelConnected is export {
    has Str $.channel;
    has Str $.topic = '';
    has DateTime $.connected-at = DateTime.now;
}

class ChannelDisconnected is export {
    has Str $.channel;
    has Str $.reason = '';
    has DateTime $.disconnected-at = DateTime.now;
}

class ChannelTopicChanged is export {
    has Str $.channel;
    has Str $.topic;
    has DateTime $.changed-at = DateTime.now;
}
