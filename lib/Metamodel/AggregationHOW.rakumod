use Metamodel::ProjectionHOW;
use Sourcing::Aggregation;
unit class Metamodel::AggregationHOW is Metamodel::ProjectionHOW;

method compose(Mu $aggregation, |) {
	callsame;
	$aggregation.^add_role: Sourcing::Aggregation;
	for $aggregation.^handled-events-map.kv -> Mu:U $event, %map {
		my $method-name = lc S:g/(\w)<?before <[A..Z]>>/$0-/ given $event.^name;
		$method-name .= subst: /'::'/, "-", :g;
		$aggregation.^add_method: $method-name, my method (\SELF: |c) {
			my $new-event = $event.new:
				|%map.kv.map(-> $from, $to {
					$to => SELF."$from"()
				}).Map,
				|c
			;
			$*SourcingConfig.emit: $new-event
				if $*SourcingConfig && !$*SourcingReplay;

			return $new-event
		}
	}
}
