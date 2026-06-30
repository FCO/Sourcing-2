use v6.e.PREVIEW;

use Metamodel::AggregationHOW;
use Sourcing::Saga;
use Sourcing::Aggregation;
use Sourcing::X::OptimisticLocked;

=begin pod

=head1 NAME

Metamodel::SagaHOW - Metaclass for saga classes

=head1 DESCRIPTION

This metaclass extends L<Metamodel::AggregationHOW> to provide the C<saga>
declaration syntax. In addition to aggregation functionality, it provides:
- State machine validation
- Automatic compensation on exceptions
- Timeout infrastructure
- Aggregation binding

=end pod

unit class Metamodel::SagaHOW is Metamodel::AggregationHOW;

my %wrapped-sagas;

method compose(Mu $saga, |) {
	$saga.^add_role: Sourcing::Saga;
	self.compose-saga-id($saga);
	self.generate-aggregation-binding($saga);
	callsame;
	self.wrap-methods-with-exception-handling($saga);
	self.wrap-apply-with-state-dispatch($saga);
}

=begin pod

=head2 method compose-saga-id

Ensures the saga class has a projection-id attribute for saga identification.

=end pod

method compose-saga-id(Mu $saga) {
	my @ids = $saga.^attributes.grep: *.?is-projection-id;
	die "Saga { $saga.^name } must have exactly one projection-id attribute"
	unless @ids == 1;
}

=begin pod

=head2 method generate-aggregation-binding

Discovers attributes typed as aggregations and generates write accessors
that emit SagaAggregationBound events.

=end pod

method generate-aggregation-binding(Mu $saga) {
	for $saga.^attributes -> $attr {
		next if $attr.name eq '$!state';
		my Mu:U $type = $attr.type;
		next if $type.^name eq 'Positional';
		next if $type.^name.starts-with('Positional[');
		# `.^does` blows up on parametric role groups (e.g. Numeric, Real) with
		# "Too many positionals", so an attribute typed with one of those would
		# otherwise crash compose. Such a type can never be an aggregation, so
		# treat an unresolvable check as "not an aggregation" and skip it.
		next unless try { $type.^does(Sourcing::Aggregation) };
		my $name = $attr.name.substr(2);
		my $attr-copy = $attr;
		$saga.^add_method: $name, my method () {
			$attr-copy.get_value(self)
		}
	}
}

=begin pod

=head2 method wrap-methods-with-exception-handling

Wraps all user-defined methods with exception handling.
Any uncaught exception triggers rollback() and transitions to 'failed' state.

=end pod

method wrap-methods-with-exception-handling(Mu $saga) {
	my $key = $saga.^name ~ '-exception';
	return if %wrapped-sagas{$key}:exists;
	%wrapped-sagas{$key} = True;

	for $saga.^methods.grep({ .name ne 'apply' && .name ne 'rollback' && .name ne 'anti-event' }) -> $method {
		next if $method.?is_wrapper;
		next if $method.name.starts-with('^');
		next if $method.name eq 'new';

		$method.wrap: method (|args) {
			CATCH {
				when Sourcing::X::OptimisticLocked { .rethrow }
				default {
					self.rollback if self.^can('rollback');
					my $state-attr = self.^attributes.first: *.name eq '$!state';
					$state-attr.set_value(self, 'failed') if $state-attr;
					.rethrow
				}
			}
			callsame
		}
	}
}

=begin pod

=head2 method wrap-apply-with-state-dispatch

Replaces the saga's C<apply> dispatch with a single state-aware dispatcher and,
in the same place, runs the state-machine transition and anti-event capture.

A saga may declare several C<apply> candidates for the same event type, each
tagged with a different C<is on-state(...)>. Native multi-dispatch cannot
disambiguate same-signature candidates, and C<.wrap> hides a candidate's
signature and its C<on-state> tag — so per-candidate wrapping cannot be combined
with this selection. Instead the C<apply> proto is wrapped once: it reads the
pristine candidates (correct signatures and C<on-state> tags), picks the one
whose tag matches the saga's current state, and invokes its body directly.

For the selected candidate this dispatcher also:

=item Builds and queues the inverse via the matching C<anti-event(EventType)>
handler (if any) B<before> running the body — under forced C<$*SourcingReplay>
with an C<@*SourcingEvents> accumulator, so the emit methods only construct the
inverse events and never emit. Because this runs inside C<apply>, which replays
on every reconstruction, the compensation queue is rebuilt durably.

=item Applies the state-machine transition afterwards: if the saga has a
C<$!state> attribute, it is set from the candidate's (defined, non-Exception)
return value.

A candidate without an C<on-state> tag is a wildcard (used by the saga's internal
events); C<on-state> candidates take precedence. When no candidate matches the
current state the event is a no-op, so duplicate or late events are dropped
instead of crashing or compensating.

=end pod

method wrap-apply-with-state-dispatch(Mu $saga) {
	my $key = $saga.^name ~ '-state-dispatch';
	return if %wrapped-sagas{$key}:exists;
	%wrapped-sagas{$key} = True;

	my $proto = $saga.^find_method: 'apply';
	return unless $proto;

	# Capture the pristine candidates up front: their signatures (for event-type
	# matching) and on-state tags are intact, and calling them runs just the body.
	my @candidates = $proto.candidates;
	my $state-attr = $saga.^attributes.first: *.name eq '$!state';
	my $has-anti   = ?($saga.^methods.first: *.name eq 'anti-event');

	# The handled event type of a candidate (first non-invocant positional).
	# Note: a Parameter's .type is a type object (undefined), so `//` must not be
	# used here — it would treat every type as "missing" and collapse to Mu.
	my sub evt-type($c) {
		with $c.signature.params.first({ !.invocant && !.named }) {
			.type
		} else {
			Mu
		}
	}

	$proto.wrap: my method (|args) {
		my $event = args[0];

		# Select the candidate for this event type whose on-state matches the
		# current state; fall back to the untagged (wildcard) candidates.
		my @cands    = @candidates.grep: *.cando: \(self, $event);
		my @stated   = @cands.grep: -> $c { $c.?on-state.defined && (self.state ~~ any($c.on-state.list)) };
		my @wildcard = @cands.grep: -> $c { !$c.?on-state.defined };
		my @group    = @stated || @wildcard;     # state-specific candidates win over wildcards

		# Within the group prefer the most specific event type, so a catch-all
		# apply(Any) never shadows a specific handler (matching native dispatch).
		# Keep a candidate when no other has a strictly narrower type. Strict
		# subtype is tested with smartmatch both ways ($td is-a $tc but not vice
		# versa) — identity (=:=) is unreliable here because Parameter.type hands
		# back a fresh wrapper each call. Count with .elems, not .first: a matching
		# type object is falsy, so the value .first returns can't signal a hit.
		my $chosen = (@group.grep: -> $c {
			my $tc = evt-type $c;
			(@group.grep: -> $d { my $td = evt-type $d; ($td ~~ $tc) && !($tc ~~ $td) }).elems == 0
		}).head // @group.head;
		return Nil without $chosen;

		# Capture the inverse event(s) for rollback before the body runs.
		if $has-anti && !$*SAGA-ROLLING-BACK {
			my $anti = self.^find_method('anti-event');
			if $anti && $anti.cando: \(self, $event) {
				my @recs = do {
					my @*SourcingEvents;
					my $*SourcingReplay = True;
					self.anti-event($event);
					@*SourcingEvents;
				};
				self.queue-compensation($_) for @recs;
			}
		}

		# Run the chosen body, then apply the state-machine transition.
		my $result = $chosen(self, $event);
		$state-attr.set_value(self, $result)
			if $state-attr && $result.defined && $result !~~ Exception;
		$result
	};
}
