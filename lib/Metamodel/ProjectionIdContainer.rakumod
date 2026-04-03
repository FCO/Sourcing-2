=begin pod

=head1 NAME

Metamodel::ProjectionIdContainer - Metaclass role for projection identity

=head1 DESCRIPTION

This role is composed into the projection metaclass to provide methods for
managing and querying projection identity attributes. It tracks which attributes
are marked as projection IDs and provides utilities for working with them.

=end pod

unit role Metamodel::ProjectionIdContainer;
use Sourcing::ProjectionId;

has @!projection-ids;

=begin pod

=head1 METHODS

=head2 multi method compose-projection-id

Collects all attributes from the class that have the L<Sourcing::ProjectionId>
role and stores them for identity tracking.

=head3 Parameters

=head4 C<Mu $proj> — The projection class being composed

=end pod

multi method compose-projection-id(Mu $proj) {
	for $proj.^attributes.grep: Sourcing::ProjectionId {
		@!projection-ids.push: .clone
	}
}

=begin pod

=head2 method projection-ids

Returns all projection ID attributes for this class.

=head3 Returns

List of attribute objects marked as projection IDs.

=end pod

method projection-ids(|)      { @!projection-ids }

=begin pod

=head2 method projection-id-names

Returns the names of all projection ID attributes, with the C<$!> prefix removed.

=head3 Returns

List of attribute names as strings (without C<$!>).

=end pod

method projection-id-names(|) { @!projection-ids.map: *.name.substr: 2 }

=begin pod

=head2 method projection-id-pairs

Returns a map of projection ID names to their current values for a given instance.

=head3 Parameters

=head4 C<$proj> — The projection instance

=head3 Returns

A L<Map> of attribute names to their values.

=end pod

method projection-id-pairs($proj --> Map()) {
	@!projection-ids.map: {
		my $name = .name.substr: 2;
		$name => $proj."$name"()
	}
}
