unit class Metamodel::ProjectionHOW is Metamodel::ClassHOW;

use Metamodel::ProjectionIdContainer;
use Metamodel::EventHandlerContainer;
use Sourcing::Projection;

also does Metamodel::ProjectionIdContainer;
also does Metamodel::EventHandlerContainer;

method compose(Mu $proj, |) {
	$proj.^add_role: Sourcing::Projection;
	$proj.^compose-projection-id;
	nextsame
}

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
