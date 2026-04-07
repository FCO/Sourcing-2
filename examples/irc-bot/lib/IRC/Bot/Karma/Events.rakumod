use v6.e.PREVIEW;

=begin pod

=head1 NAME

IRC::Bot::Karma::Events - Karma events for IRC bot

=head1 DESCRIPTION

Events emitted by karma aggregations.

=end pod

class KarmaIncreased is export {
    has Str $.target;
    has Str $.changed-by;
    has Int $.amount = 1;
    has DateTime $.changed-at;
}

class KarmaDecreased is export {
    has Str $.target;
    has Str $.changed-by;
    has Int $.amount = 1;
    has DateTime $.changed-at;
}

class NickChanged is export {
    has Str $.target;
    has Str $.old-nickname;
    has Str $.new-nickname;
    has Str $.changed-by;
    has DateTime $.changed-at;
}
