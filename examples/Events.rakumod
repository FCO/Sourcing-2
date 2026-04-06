use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Example::IRC::Events - Event definitions for IRC broadcast saga

=head1 DESCRIPTION

Events that drive the IRC broadcast saga:

=item B<ChannelMessageSent> - A message was successfully sent to a channel
=item B<ChannelSendFailed> - Sending to a channel failed
=item B<UserMessageSent> - Confirmation sent back to the original user
=item B<BroadcastCompleted> - All broadcasts finished successfully
=item B<BroadcastFailed> - Broadcast failed with reason

=end pod

unit module Sourcing::Example::IRC::Events;

# Domain Events
class ChannelMessageSent is export {
    has Str $.saga-id;
    has Str $.channel;
    has Str $.message;
    has Str $.sender;
    has DateTime $.sent-at;
}

class ChannelSendFailed is export {
    has Str $.saga-id;
    has Str $.channel;
    has Str $.reason;
    has DateTime $.failed-at;
}

class UserMessageSent is export {
    has Str $.saga-id;
    has Str $.user;
    has Str $.channel;
    has DateTime $.sent-at;
}

class BroadcastCompleted is export {
    has Str $.saga-id;
    has Int $.channels-broadcast;
    has DateTime $.completed-at;
}

class BroadcastFailed is export {
    has Str $.saga-id;
    has Str $.reason;
    has Int $.successful-sends;
    has Int $.failed-sends;
    has DateTime $.failed-at;
}
