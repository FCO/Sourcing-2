use Sourcing;
use Broadcast::Events;

# A chat channel. Records the messages posted to it (so callers can see both the
# original broadcast and any later retraction). A disconnected channel rejects
# the send command — but the saga's compensation uses the emit method directly,
# so a retraction is recorded regardless.
aggregation ChannelAggregate {
    has Str  $.channel is projection-id;
    has Str  @.messages;
    has Bool $.connected = True;

    method message-count(--> Int) { @!messages.elems }

    multi method apply(ChannelMessageSent $e) {
        @!messages.push: $e.message;
    }

    method send-message(Str :$message, Str :$sender) is command {
        die "Channel $!channel is disconnected" unless $!connected;
        $.channel-message-sent: :$message, :$sender;
    }
}
