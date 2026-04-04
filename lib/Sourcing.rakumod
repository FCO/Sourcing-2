use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing - Event sourcing library for Raku

=head1 DESCRIPTION

Sourcing is a Raku event sourcing library that provides projections and aggregations
for building event-driven applications. It uses metaclasses for projections and
aggregations, with roles for composition.

=head1 SYNOPSIS

    use Sourcing;

    class MyProjection is Sourcing::Projection {
        has $.id is projection-id;
        has $.name;

        method apply(MyEvent $e) { ... }
    }

=end pod

use Sourcing::Projection;
use Sourcing::ProjectionId;
use Sourcing::ProjectionIdMap;
use Sourcing::X::OptimisticLocked;

my package EXPORTHOW {
	package DECLARE {
		use Metamodel::ProjectionHOW;
		use Metamodel::AggregationHOW;

		constant projection  = Metamodel::ProjectionHOW;
		constant aggregation = Metamodel::AggregationHOW;
	}
}

=begin pod

=head1 VARIABLES

=head2 sub sourcing-config

Global configuration variable for the current sourcing context.
Returns a Process variable that stores the active plugin configuration.

=end pod

sub sourcing-config is rw is export {
	PROCESS::<$SourcingConfig>
}

=begin pod

=head1 SUBROUTINES

=head2 sub sourcing

Creates a fresh projection/aggregation instance, applying all events
from the event store for the given identity.

=head3 Parameters

=head4 C<$proj> — The projection type to instantiate (must be a L<Sourcing::Projection>)

=head4 C<*%ids> — Named arguments for the projection's identity attributes

=head3 Returns

A new instance of the projection type with all relevant events applied.
Each call to C<sourcing> creates a fresh instance; it does not return
cached instances.

=head3 Example

    my $projection = sourcing MyProjection, :id($some-id);

=end pod

sub sourcing(Sourcing::Projection:U $proj, *%ids) is export {
	my %map{Mu:U} = $proj.^handled-events-map;
	my @initial-events = $*SourcingConfig.get-events-after: -1, %ids, %map;

	my $new = $proj.new: |%ids, :@initial-events;
	$new.^attributes.first(*.name eq '$!__current-version__').set_value: $new, @initial-events.elems - 1;

	$*SourcingConfig.store-cached-data: $new, :last-id(@initial-events.elems - 1);
	$new
}

=begin pod

=head1 TRAITS

=head2 trait_mod:<is>

Custom traits for marking methods as commands and attributes as projection identifiers.

=head3 trait_mod:<is>(Method $m, Bool :$command)

Marks a method as a command. When called, the method is wrapped in a
retry loop that:

1. Calls C<^update> to reset and replay the aggregate from the event store
2. Executes the command body (validation and event emission)
3. If C<Sourcing::X::OptimisticLocked> is thrown during event emission,
   the loop retries from step 1 (up to 5 attempts total)
4. Non-locking exceptions (e.g., validation errors) are re-thrown
   immediately without retry
5. After exhausting all 5 attempts, the last C<X::OptimisticLocked>
   exception is re-thrown

=head3 trait_mod:<is>(Method $m, :$projection-id-map)

Associates a method with a projection ID map, allowing custom event-to-attribute mappings.

=head3 trait_mod:<is>(Method $r, Str :$projection-id)

Marks a method as providing a projection identifier. The method's return value
becomes part of the aggregate's identity for event correlation.

=head3 trait_mod:<is>(Attribute $r, Bool :$projection-id)

Marks an attribute as a projection identifier. This attribute's value is used
to correlate events with specific projection instances.

=end pod

multi trait_mod:<is>(Method $m, Bool :$command where *.so) is export {
	$m.wrap: method (|c) {
		my &next = nextcallee;
		my $success = False;
		my $result;
		my $last-exception;
		for ^5 {
			self.^update;
			try {
				$result = next(self, |c);
				$success = True;
				CATCH {
					when Sourcing::X::OptimisticLocked {
						$last-exception = $_;
					}
					default {
						.rethrow;
					}
				}
			}
			last if $success;
		}
		$success ?? $result !! $last-exception.throw
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
