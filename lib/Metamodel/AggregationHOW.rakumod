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

# Reverse index: event class name => the aggregation type that handles it.
# Populated at compose time and used to discover the target stream for an
# anti-event, the same way an event's id/owner is discovered elsewhere.
my %aggregation-for-event;

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
		%aggregation-for-event{$event.^name} = $aggregation;

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

			my %ids = $aggregation.HOW.projection-id-pairs(SELF);

			if $*SourcingConfig && !$*SourcingReplay {
				$*SourcingConfig.emit: $new-event,
					:type(SELF.WHAT),
					:ids(%ids),
					:$current-version;
				$curr-version-attr.set_value: SELF, $current-version + 1;
			}

			return $new-event
		}
	}
}

=begin pod

=head2 method aggregation-for-event

Returns the aggregation type that handles events of the given type (the owner of
that event's stream), or C<Nil> if none is known. Used to discover the target
stream and ids for an anti-event from the event alone.

=end pod

method aggregation-for-event($, Mu:U $event-type) {
	my $name = $event-type.^name;
	%aggregation-for-event{$name}:exists ?? %aggregation-for-event{$name} !! Nil
}
