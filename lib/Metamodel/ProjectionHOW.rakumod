=begin pod

=head1 NAME

Metamodel::ProjectionHOW - Metaclass for projection classes

=head1 DESCRIPTION

This metaclass extends C<Metamodel::ClassHOW> to provide the C<is projection>
declaration syntax. It composes the L<Sourcing::Projection> role into classes
and manages projection-specific behavior including identity tracking and
event handling.

=end pod

unit class Metamodel::ProjectionHOW is Metamodel::ClassHOW;

use Metamodel::ProjectionIdContainer;
use Metamodel::EventHandlerContainer;
use Sourcing::Projection;

also does Metamodel::ProjectionIdContainer;
also does Metamodel::EventHandlerContainer;

=begin pod

=head1 METHODS

=head2 method compose

Completes the class composition process. Adds the L<Sourcing::Projection>
role to the class and composes projection ID information.

=head3 Parameters

=head4 C<Mu $proj> — The projection class being composed

=head4 C<|> — Additional arguments passed to C<nextsame>

=head3 Returns

The result of the parent C<compose> method.

=end pod

method compose(Mu $proj, |) {
	$proj.^add_role: Sourcing::Projection;
	$proj.^compose-projection-id;
	nextsame
}

=begin pod

=head2 method update

Applies any new events that have occurred since the last known version.
This is called when a command method is invoked on an aggregate.

=head3 Parameters

=head4 C<$proj> — The projection or aggregate instance to update

=head3 Returns

The new version ID after applying events.

=end pod

method update($proj) {
	my %ids = $proj.^projection-id-pairs;
	my $attr    = $proj.^attributes.first: *.name eq '$!__current-version__';
	my $last-id = $attr.get_value($proj) // -1;

	my %map{Mu:U} = $proj.^handled-events-map;
	my @initial-events = $*SourcingConfig.get-events-after: $last-id, %ids, %map;

	$proj.apply: $_ for @initial-events;

	$attr.set_value: $proj, my $new-id = $last-id + @initial-events;
	$new-id
}
