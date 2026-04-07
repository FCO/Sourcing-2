use v6.e.PREVIEW;

use Sourcing;
use IRC::Bot::Karma::Events;

=begin pod

=head1 NAME

IRC::Bot::Karma::Aggregation - Karma aggregation

=head1 DESCRIPTION

The Karma aggregation manages karma scores for users/nicknames.
Handles commands for incrementing, decrementing, and changing nicknames.
Emits appropriate events.

=end pod

aggregation IRC::Bot::Karma::Aggregation {

    has Str $.target is projection-id;

    # Karma state
    has Int $.score = 0;
    has Int $.increases = 0;
    has Int $.decreases = 0;

    =begin pod

    =head2 Method apply

    Event handlers to rebuild aggregate state from events.

    =end pod

    multi method apply(KarmaIncreased $e) {
        $!score = $!score + $e.amount;
        $!increases++;
    }

    multi method apply(KarmaDecreased $e) {
        $!score = $!score - $e.amount;
        $!decreases++;
    }

    multi method apply(NickChanged $e) {
        # Nick change is handled by the alias system
    }

    =begin pod

    =head2 Method increment-karma

    Command to increment karma for a target.
    Emits a KarmaIncreased event only - NO return value, NO response.

    =end pod

    method increment-karma(Str :$changed-by, Int :$amount = 1) is command {
        self.karma-increased:
            :$changed-by,
            :$amount,
            :changed-at(DateTime.now)
    }

    =begin pod

    =head2 Method decrement-karma

    Command to decrement karma for a target.
    Emits a KarmaDecreased event only - NO return value, NO response.

    =end pod

    method decrement-karma(Str :$changed-by, Int :$amount = 1) is command {
        self.karma-decreased:
            :$changed-by,
            :$amount,
            :changed-at(DateTime.now)
    }

    =begin pod

    =head2 Method change-nick

    Command to change nickname (handled by alias aggregation).
    Emits a NickChanged event only - NO return value.

    =end pod

    method change-nick(Str :$old-nickname, Str :$new-nickname, Str :$changed-by) is command {
        self.nick-changed:
            :$old-nickname,
            :$new-nickname,
            :$changed-by,
            :changed-at(DateTime.now)
    }
}
