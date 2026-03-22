use Sourcing::Projection;
use Sourcing::ProjectionId;
use Sourcing::ProjectionIdMap;

my package EXPORTHOW {
	package DECLARE {
		use Metamodel::ProjectionHOW;
		use Metamodel::AggregationHOW;

		constant projection  = Metamodel::ProjectionHOW;
		constant aggregation = Metamodel::AggregationHOW;
	}
}

sub sourcing-config is rw is export {
	PROCESS::<%SourcingConfig> //= %()
}

# TODO: Add id to events and store it 
# TODO: Export this sub to an different file to be able to add Projection.^refresh
sub sourcing(Sourcing::Projection:U $proj, *%ids) is export {
	my %map{Mu:U} = $proj.^handled-events-map;
	my :(:$last-id, :%data) := $*SourcingConfig.get-cached-data: $proj, %ids;
	my @initial-events = $*SourcingConfig.get-events-after: $last-id, %ids, %map;
	# my $*SourcingReplay = True;

	my $new = $proj.new: |%ids, |%data, :@initial-events;
	$new.^attributes.first(*.name eq '$!__current-version__').set_value: $new, $last-id;

	$*SourcingConfig.store-cached-data: $new, :last-id($last-id + @initial-events);
	$new
}

multi trait_mod:<is>(Method $m, Bool :$command where *.so) is export {
	$m.wrap: method (|) {
		self.^update;
		nextsame
	}
}

multi trait_mod:<is>(Method $m, Bool :$command where *.not) is export {
	$m does role NotCommand { method is-not-a-command { True } }
}

multi trait_mod:<is>(Attribute $r, Bool :$projection-id where *.so) is export {
	$r does Sourcing::ProjectionId;
}

multi trait_mod:<is>(Method $m, :%projection-id-map) is export {
	$m does Sourcing::ProjectionIdMap(%projection-id-map);
}

multi trait_mod:<is>(Method $r, Str :$projection-id) is export {
	my $proj = $r.signature.params.head.type;
	my @ids  = $proj.^attributes.grep: *.?is-projection-id;
	die "Trying to set a generic projection id to a method on a type with multiple or no projection ids (@ids.join(", "))"
	unless @ids == 1;
	trait_mod:<is>($r, :projection-id-map{ @ids.head.name.substr(2) => $projection-id })
}
