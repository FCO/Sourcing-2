=begin pod

=head1 NAME

Sourcing::Aggregation - Role for aggregate root objects

=head1 DESCRIPTION

This role is automatically composed into classes declared with C<is aggregation>.
Aggregates are aggregate roots in event sourcing - they own the process of
creating and emitting events, and maintain their own state by applying events.

Aggregates differ from projections in that they emit events (via auto-generated
methods from the handled events map) while projections only consume events.

=end pod

unit role Sourcing::Aggregation;
