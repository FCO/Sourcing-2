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

Returns the state or states this candidate is guarded by (a single value, a
list, or a junction).

=head2 method matches($state)

Returns whether C<$state> satisfies this tag. A list (C<Positional>) is treated
as membership (C<$state ~~ any(@states)>); anything else — a single string or a
junction such as C<'a' | 'b'> or C<none &lt;a b&gt;> — is smartmatched directly
(C<$on-state ~~ $state>), so junctions autothread as expected.

=end pod

method on-state { $!on-state }

method matches($state) {
	$!on-state ~~ Positional
		?? ($state ~~ any($!on-state.list))
		!! ($!on-state ~~ $state)
}
