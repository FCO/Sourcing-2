# Broadcast example events. Declared as bare top-level classes (like
# Hotel::Events) so their kebab-case emit methods stay unprefixed
# (channel-message-sent, not broadcast-events-channel-message-sent).

# Channel-stream event (what a channel records).
class ChannelMessageSent is export {
    has Str $.channel;
    has Str $.message;
    has Str $.sender;
}

# Saga-stream trigger events (keyed by saga-id).
class ChannelTargeted is export {
    has Str $.saga-id;
    has Str $.channel;
    has Str $.message;
    has Str $.user;
}

class BroadcastAborted is export {
    has Str $.saga-id;
}
