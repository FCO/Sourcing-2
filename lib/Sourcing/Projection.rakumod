unit role Sourcing::Projection;

=begin pod

=head1 NAME

Sourcing::Projection - Role for projection objects in event sourcing

=head1 DESCRIPTION

This role is automatically composed into classes declared with C<is projection>.
It provides the base infrastructure for projections including event application
and version tracking.

=end pod

has $!__current-version__;

=begin pod

=head1 METHODS

=head2 method new

Creates a new projection instance, optionally applying initial events.

=head3 Parameters

=head4 C<:@initial-events> — Positional array of events to apply upon construction

=head4 C<|c> — Additional arguments passed to C<bless>

=head3 Returns

A new instance of the projection with all initial events applied via C<apply>.

=end pod

multi method new(:@initial-events!, |c) {
	my $obj = self.bless: |c;
	for @initial-events -> $event {
		$obj.apply: $_ with $event;
	}
	$obj
}
