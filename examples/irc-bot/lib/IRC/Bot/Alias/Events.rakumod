use v6.e.PREVIEW;

=begin pod

=head1 NAME

IRC::Bot::Alias::Events - Alias events for IRC bot

=head1 DESCRIPTION

Events emitted by alias aggregations.

=end pod

class AliasSet is export {
    has Str $.alias;
    has Str $.command;
    has Str $.set-by;
    has DateTime $.set-at;
}

class AliasRemoved is export {
    has Str $.alias;
    has Str $.removed-by;
    has DateTime $.removed-at;
}
