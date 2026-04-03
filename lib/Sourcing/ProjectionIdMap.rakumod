=begin pod

=head1 NAME

Sourcing::ProjectionIdMap - Role for projection ID mapping

=head1 DESCRIPTION

This role is composed into methods that have custom projection ID mappings.
It allows event attributes to be mapped to different projection attribute names,
providing flexibility in how events correlate with projection state.

=end pod

unit role Sourcing::ProjectionIdMap;
use Sourcing::ProjectionId;

has Str %.projection-id-map{Str};

=begin pod

=head1 METHODS

=head2 method projection-id-map

Returns the mapping of projection attribute names to event attribute names.

=head3 Returns

A hash mapping projection attribute names (without C<$!>) to event attribute names.

=end pod

method projection-id-map { %!projection-id-map }
