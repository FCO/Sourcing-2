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
	PROCESS::<%SourcingConfig> //= %()
}

=begin pod

=head1 SUBROUTINES

=head2 sub sourcing

Creates or retrieves a projection instance, applying any initial events
that have occurred since the last cached version.

=head3 Parameters

=head4 C<$proj> — The projection type to instantiate (must be a L<Sourcing::Projection>)

=head4 C<*%ids> — Named arguments for the projection's identity attributes

=head3 Returns

A new or cached instance of the projection type with all relevant events applied.

=head3 Example

    my $projection = sourcing MyProjection, :id($some-id);

=end pod

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

=begin pod

=head1 TRAITS

=head2 trait_mod:<is>

Custom traits for marking methods as commands and attributes as projection identifiers.

=head3 trait_mod:<is>(Method $m, Bool :$command)

Marks a method as a command. When called, the method will first call C<^update>
on the object to apply any new events before executing the command logic.

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
