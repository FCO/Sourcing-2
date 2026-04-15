use Metamodel::ProjectionHOW;
use Sourcing::Aggregation;

=begin pod

=head1 NAME

Metamodel::AggregationHOW - Metaclass for aggregate root classes

=head1 DESCRIPTION

This metaclass extends C<Metamodel::ProjectionHOW> to provide the C<is aggregation>
declaration syntax. In addition to projection functionality, it generates command
methods from the handled events map - each event type gets an auto-generated method
that creates and emits the corresponding event.

=end pod

unit class Metamodel::AggregationHOW is Metamodel::ProjectionHOW;

=begin pod

=head1 METHODS

=head2 method compose

Completes the aggregate class composition. After calling the parent's compose
(which adds the L<Sourcing::Projection> role), it adds the L<Sourcing::Aggregation>
role and generates command methods for each handled event type.

=head3 Parameters

=head4 C<Mu $aggregation> — The aggregate class being composed

=head4 C<|> — Additional arguments

=end pod

method compose(Mu $aggregation, |) {
	$aggregation.^add_role: Sourcing::Aggregation;
	callsame;
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
			my $curr-version-attr = $.^attributes.first: *.name eq '$!__current-version__';
			my $current-version = $curr-version-attr.get_value(SELF) // -1;

			if $*SourcingConfig && !$*SourcingReplay {
				$*SourcingConfig.emit: SELF, $new-event;
				$curr-version-attr.set_value: SELF, $current-version + 1;
			}

			return $new-event
		}
	}
}
