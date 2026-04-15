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

Resets and replays the aggregate from the event store:
1. Creates a fresh instance to obtain default attribute values
2. Resets all mutable attributes (preserving projection-id attributes)
3. Fetches all events for the given identity from the store (starting from version -1)
4. Applies each event via $proj.apply: $event
5. Updates $!__current-version__ to total events applied minus one
6. Stores updated cached data via $*SourcingConfig.store-cached-data

This ensures the aggregate always reflects a clean, current snapshot
of the event stream, with no stale state from previous operations.

=head3 Parameters

=head4 C<$proj> — The projection or aggregate instance to update

=head3 Returns

The new version ID after replaying all events.

=end pod

method update($proj) {
	my %ids = $proj.^projection-id-pairs;
	my %cached = $*SourcingConfig.get-cached-data($proj.WHAT, %ids);
	my $last-id = %cached<last-id> // -1;
	my %cached-data = %cached<data> ~~ Associative ?? %(%cached<data>) !! %();

	my $fresh = $proj.WHAT.new: |%cached-data, |%ids;
	my $proj-ids = $proj.^projection-ids.map(*.name).Set;
	for $proj.^attributes.grep({ !$proj-ids{.name} && .name ne '$!__current-version__' && .has_accessor }) -> $attr {
		$attr.set_value: $proj, $attr.get_value($fresh);
	}

	my $attr    = $proj.^attributes.first: *.name eq '$!__current-version__';

	my %map{Mu:U} = $proj.^handled-events-map;

	# Set $*SourcingReplay to prevent command execution during replay
	my $*SourcingReplay = True;
	my @initial-events = $*SourcingConfig.get-events-after: $last-id, %ids, %map;

	$proj.apply: $_ for @initial-events;

	$attr.set_value: $proj, my $new-id = $last-id + @initial-events.elems;

	$*SourcingConfig.store-cached-data: $proj, :last-id($new-id);

	$new-id
}
