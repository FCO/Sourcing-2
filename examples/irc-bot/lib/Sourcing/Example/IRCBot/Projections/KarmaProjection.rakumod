use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::IRCBot::Events;

=begin pod

=head1 NAME

Sourcing::Example::IRCBot::Projections::KarmaProjection - Karma tracking projection

=head1 DESCRIPTION

A read model that tracks karma scores for users and topics.
Supports karma increases (++) and decreases (--) with configurable limits.

=end pod

projection Sourcing::Example::IRCBot::Projections::KarmaProjection {

has Str $.target is projection-id;
has Int $.score = 0;
has Int $.increases = 0;
has Int $.decreases = 0;
has Str @.history;

# Configuration
has Int $.min = -10;
has Int $.max = 10;

=begin pod

=head2 Method apply

Apply events to update the karma projection.

=end pod

multi method apply(KarmaIncreased $e) {
    $!score = ($!score + $e.amount).min($.max);
    $!increases++;
    @.history.push: "++$e.amount by $e.changed-by";
}

multi method apply(KarmaDecreased $e) {
    $!score = ($!score - $e.amount).max($.min);
    $!decreases++;
    @.history.push: "--$e.amount by $e.changed-by";
}

multi method apply(KarmaReset $e) {
    $!score = 0;
    $!increases = 0;
    $!decreases = 0;
    @.history = ();
}

=begin pod

=head2 Method status

Returns a status string for the karma.

=end pod

method status() {
    my $status = $!score > 0 ?? "good" !! $!score < 0 ?? "bad" !! "neutral";
    "{$!score} ($status)";
}

=begin pod

=head2 Method top

Returns users sorted by karma score.

=end pod

method top(Int $n = 5) {
    my @all = self.^load-all;
    @all.sort({ $^b.score <=> $^a.score }).head($n);
}
}
