use v6.e.PREVIEW;

use Sourcing;
use IRC::Bot::Channel::Events;
use IRC::Bot::Alias::Aggregation;

=begin pod

=head1 NAME

IRC::Bot::Saga::AliasHandler - Alias handling saga

=head1 DESCRIPTION

A saga that listens for MessageReceived events and:
- Detects nick=>newNick patterns
- Calls alias aggregation commands

This saga ONLY emits commands (through aggregations), never queries projections.

=end pod

unit saga IRC::Bot::Saga::AliasHandler;

has Str $.channel is projection-id;

=begin pod

=head2 Method apply

Event handlers to rebuild saga state from events.

=end pod

multi method apply(MessageReceived $e) {
    self.process-message: $e;
}

=begin pod

=head2 Method process-message

Process a received message and handle alias commands.

=end pod

method process-message(MessageReceived $e) {
    my $text = $e.message;
    my $nick = $e.nick;

    # Handle nick change: nick=>newNick
    if $text ~~ /^(\S+) '=' '>' (\S+)$/ {
        my $old-nick = ~$0;
        my $new-nick = ~$1;
        return self.handle-nick-change($old-nick, $new-nick, $nick);
    }
}

=begin pod

=head2 Method handle-nick-change

Handles nickname change by:
1. Setting alias for new nick pointing to old nick's karma
2. (Optionally) transferring karma - but we'll keep it simple and just create alias

=end pod

method handle-nick-change(Str $old-nick, Str $new-nick, Str $changed-by) {
    # Create an alias so that !karma newnick will work
    # We'll use a special syntax: the alias maps to a command that shows the old nick's karma
    my $aggregate = sourcing IRC::Bot::Alias::Aggregation, :alias($new-nick);
    $aggregate.set-alias: :command("karma $old-nick"), :set-by($changed-by);

    # NOTE: We do NOT return anything, do NOT query projections
    # Commands only emit events - responses come from separate query plugins
}
