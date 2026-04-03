=begin pod

=head1 NAME

Sourcing::ProjectionId - Role for marking projection identity attributes

=head1 DESCRIPTION

This role is composed into attributes that are marked with C<is projection-id>.
It marks an attribute as being part of a projection's identity, used to correlate
events with specific projection instances.

=end pod

unit role Sourcing::ProjectionId;

=begin pod

=head1 METHODS

=head2 method is-projection-id

Returns C<True> to indicate this attribute is a projection identifier.

=head3 Returns

C<True>

=end pod

method is-projection-id { True }
