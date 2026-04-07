use v6.e.PREVIEW;

use Sourcing;
use IRC::Bot::Channel::Events;

=begin pod

=head1 NAME

IRC::Bot::Channel::Aggregation - IRC channel aggregation

=head1 DESCRIPTION

The Channel aggregation manages IRC channel state and handles commands
related to messages received in channels. Emits MessageReceived events
when messages are received.

=end pod

aggregation IRC::Bot::Channel::Aggregation {

    has Str $.channel is projection-id;

    # Channel state
    has Int $.message-count = 0;

    =begin pod

    =head2 Method apply

    Event handlers to rebuild aggregate state from events.

    =end pod

    multi method apply(MessageReceived $e) {
        $!message-count++;
    }

    =begin pod

    =head2 Method receive-message

    Command to process a message received in the channel.
    Emits a MessageReceived event.

    =end pod

    method receive-message(Str :$nick, Str :$message) is command {
        self.message-received(
            :channel($!channel),
            :$nick,
            :$message,
            :timestamp(DateTime.now)
        );
    }
}
