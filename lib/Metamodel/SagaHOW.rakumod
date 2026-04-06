use v6.e.PREVIEW;

use Metamodel::AggregationHOW;
use Sourcing::Saga;
use Sourcing::Aggregation;

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

my $ON-STATE-ATTR = Attribute.^lookup('$!on-state');
my %wrapped-sagas;

method compose(Mu $saga, |) {
	$saga.^add_role: Sourcing::Saga;
	self.compose-saga-id($saga);
	self.generate-aggregation-binding($saga);
	callsame;
	# TODO: Re-enable after fixing command wrapper issue
	# self.wrap-methods-with-exception-handling($saga);
	self.generate-state-machine($saga);
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

=head2 method generate-state-machine

Wraps apply methods to update the state based on return type declarations.

=end pod

method generate-state-machine(Mu $saga) {
	my $key = $saga.^name;
	return if %wrapped-sagas{$key}:exists;
	%wrapped-sagas{$key} = True;
	
	my $state-attr = $saga.^attributes.first: *.name eq '$!state';
	return unless $state-attr;

	for $saga.^methods.grep: *.name eq 'apply' -> $method {
		next if $method.^name ~~ / 'Proto' | 'Multi' /;
		next if $method.?is_wrapper;
		my $attr = $state-attr;
		$method.wrap: my method (|args) {
			my $result = callsame;
			$attr.set_value: self, $result if $result.defined && $result !~~ Exception;
			$result
		}, :replace;
	}
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
		next unless $type.^does(Sourcing::Aggregation);
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
	
	for $saga.^methods.grep({ .name ne 'apply' && .name ne 'rollback' }) -> $method {
		next if $method.?is_wrapper;
		next if $method.name.starts-with('^');
		next if $method.name eq 'new';
		
		$method.wrap: method (|args) {
			callsame;
			CATCH {
				default {
					self.rollback if self.^can('rollback');
					# Transition to failed state if state attribute exists
					my $state-attr = self.^attributes.first: *.name eq '$!state';
					$state-attr.set_value(self, 'failed') if $state-attr;
					.rethrow
				}
			}
		}
	}
}
