use v6.e.PREVIEW;

use Sourcing;
use IRC::Bot::Channel::Events;
use IRC::Bot::Karma::Aggregation;

=begin pod

=head1 NAME

IRC::Bot::Saga::KarmaHandler - Karma handling saga

=head1 DESCRIPTION

A saga that listens for MessageReceived events and:
- Detects nick++ / nick-- patterns
- Calls karma aggregation commands

This saga ONLY emits commands (through aggregations), never queries projections.

=end pod

unit saga IRC::Bot::Saga::KarmaHandler;

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

Process a received message and handle karma commands.

=end pod

method process-message(MessageReceived $e) {
    my $text = $e.message;
    my $nick = $e.nick;

    # Handle karma increment/decrement with a single match
    if $text ~~ /^ (\+\+|\-\-) (\S+) $/ || $text ~~ /^ (\S+) (\+\+|\-\-) $/ {
        my $op = ~$0 eq '++' || ~$1 eq '++' ?? '++' !! '--';
        my $target = ~$0 eq '++' || ~$0 eq '--' ?? ~$1 !! ~$0;
        return $op eq '++'
            ?? self.handle-karma-increment($target, $nick)
            !! self.handle-karma-decrement($target, $nick);
    }
}

=begin pod

=head2 Method handle-karma-increment

Calls the increment-karma command on the Karma aggregation.

=end pod

method handle-karma-increment(Str $target, Str $changed-by) {
    my $aggregate = sourcing IRC::Bot::Karma::Aggregation, :target($target);
    $aggregate.increment-karma: :$changed-by;

    # NOTE: We do NOT return anything, do NOT query projections
    # Commands only emit events - responses come from separate query plugins
}

=begin pod

=head2 Method handle-karma-decrement

Calls the decrement-karma command on the Karma aggregation.

=end pod

method handle-karma-decrement(Str $target, Str $changed-by) {
    my $aggregate = sourcing IRC::Bot::Karma::Aggregation, :target($target);
    $aggregate.decrement-karma: :$changed-by;

    # NOTE: We do NOT return anything, do NOT query projections
    # Commands only emit events - responses come from separate query plugins
}
