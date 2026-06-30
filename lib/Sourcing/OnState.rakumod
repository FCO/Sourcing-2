=begin pod

=head1 NAME

Sourcing::OnState - Role tagging a saga apply candidate with its guard state(s)

=head1 DESCRIPTION

This role is mixed into an C<apply> (or command) method candidate by the
C<is on-state(...)> trait. It records the state — or list of states — in which
that candidate is allowed to run. The saga metaclass reads this tag to select,
among several same-event candidates, the one whose state matches the saga's
current state. A candidate without this tag is a wildcard that runs in any state.

=end pod

unit role Sourcing::OnState;

has $.on-state;

=begin pod

=head1 METHODS

=head2 method on-state

Returns the state or states this candidate is guarded by (a single value or a
list).

=end pod

method on-state { $!on-state }
