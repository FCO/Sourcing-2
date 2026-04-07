use v6.e.PREVIEW;

=begin pod

=head1 NAME

IRC::Bot::Channel::Events - Channel events for IRC bot

=head1 DESCRIPTION

Events emitted by channel aggregations.

=end pod

class MessageReceived is export {
    has Str $.channel;
    has Str $.nick;
    has Str $.message;
    has DateTime $.timestamp;
}
