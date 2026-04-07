use v6.e.PREVIEW;

use Sourcing;
use IRC::Bot::Karma::Events;

=begin pod

=head1 NAME

IRC::Bot::Projections::KarmaProjection - Karma projection

=head1 DESCRIPTION

A read model that tracks karma scores for users and topics.

=end pod

projection IRC::Bot::Projections::KarmaProjection {

    has Str $.target is projection-id;
    has Int $.score = 0;
    has Int $.increases = 0;
    has Int $.decreases = 0;

    multi method apply(KarmaIncreased $e) {
        $!score = $!score + $e.amount;
        $!increases++;
    }

    multi method apply(KarmaDecreased $e) {
        $!score = $!score - $e.amount;
        $!decreases++;
    }

    multi method apply(NickChanged $e) {
        # Nick change tracking handled separately
    }

    method status() {
        my $status = $!score > 0 ?? "good" !! $!score < 0 ?? "bad" !! "neutral";
        "{$!score} ($status)";
    }
}
