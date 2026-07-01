use Sourcing;
use Broadcast::Events;
use Broadcast::ChannelAggregate;

# Broadcasts a message across channels, event-driven. Each channel send is its
# own ChannelTargeted event; the saga reacts by sending the message and declares
# its inverse with anti-event (a retraction). The framework queues those inverses
# and, on rollback, emits them in reverse order — so aborting a broadcast retracts
# exactly the channels that received it, newest first, with no manual bookkeeping.
#
#   idle/broadcasting --ChannelTargeted--> broadcasting   (send to one channel)
#   broadcasting      --BroadcastAborted--> aborted        (rollback: retract, reversed)
saga BroadcastSaga {
    has Str $.saga-id is projection-id;
    has Str $.state = 'idle';

    # Send the message to one channel. Valid while idle or already broadcasting.
    multi method apply(ChannelTargeted (:$channel, :$message, :$user, |))
        is on-state(<idle broadcasting>)
    {
        sourcing(ChannelAggregate, :$channel).send-message: :$message, :sender($user);
        'broadcasting'
    }

    # Abort: rollback emits the queued retractions in reverse order.
    multi method apply(BroadcastAborted $) is on-state('broadcasting') {
        self.rollback;
        'aborted'
    }

    # The inverse of a channel send: post a retraction to the same channel. We use
    # the emit method (not the send-message command) so the compensation bypasses
    # the "is it connected?" guard — it undoes a fact that already happened.
    multi method anti-event(ChannelTargeted (:$channel, :$message, |)) {
        sourcing(ChannelAggregate, :$channel).channel-message-sent:
            :message("[Retracted] $message"), :sender('bot');
    }
}
