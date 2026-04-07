use v6.e.PREVIEW;

use Sourcing;
use IRC::Bot::Channel::Events;

=begin pod

=head1 NAME

IRC::Bot::Projections::ChannelLogProjection - Channel message log projection

=head1 DESCRIPTION

A read model that stores all messages received in a channel.

=end pod

projection IRC::Bot::Projections::ChannelLogProjection {

    has Str $.channel is projection-id;
    has Int $.message-count = 0;
    has Str @.recent-messages;

    # Keep last 100 messages
    constant MAX_MESSAGES = 100;

    multi method apply(MessageReceived $e) {
        $!message-count++;
        my $msg = "[{$e.timestamp.Str}] <{$e.nick}> {$e.message}";
        @!recent-messages.push: $msg;
        @!recent-messages = @.recent-messages.tail(MAX_MESSAGES);
    }

    method messages() {
        @!recent-messages
    }

    method log-file() {
        "{$!channel}.log"
    }
}
