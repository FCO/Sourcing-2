use v6.e.PREVIEW;
use Sourcing;
use Sourcing::Projection;

=begin pod

=head1 NAME

Sourcing::ProjectionStorage - Built-in projection storage and registry

=head1 DESCRIPTION

This is the built-in storage implementation that acts as both a registry for
projection types and a coordinator for event distribution. It listens to the
global event supply and creates/updates projections as events are emitted.

=end pod

unit aggregation Sourcing::ProjectionStorage;

my class ProjectionRegistered {
	has Mu:U $.type;
	has Str  $.name    = $!type.^name;
	has Str  @.ids     = $!type.^projection-id-names;
	has Hash %.map{Mu} = $!type.^handled-events-map;
}

my class Registry {
	has Str  $.name;
	has Mu:U $.type;
	has      @.ids;
	has      %.map;
}

has $.id is projection-id = 1;
has %.registries;
has $.supply;

=begin pod

=head1 METHODS

=head2 method start

Starts the projection storage's event processing. Creates a supply that
listens to the global event supply and applies events to registered projections.

=head3 Returns

The internal L<Supply> that processes events.

=end pod

method start {
	$!supply = supply {
		my $s = sourcing self.WHAT;
		whenever $*SourcingConfig.supply -> $event {
			$s.apply: $event
		}
	}
	my $p = Promise.new;
	$!supply.tap:
		done => { $p.keep: 'done' },
		quit => -> $ex { $p.break: $ex };
	$p
}

=begin pod

=head2 multi method apply

Handles registration of a new projection type.

=head3 Parameters

=head4 C<ProjectionRegistered> — Registration data containing the type, name, and event mapping

=end pod

multi method apply(ProjectionRegistered (Mu:U :$type, Str :$name, :%map, :@ids)) {
	for %map.kv -> $event, %ids {
		%!registries.push: $event.^name => Registry.new: :$type, :$name, :map(%ids), :@ids
	}
}

=begin pod

=head2 method register

Registers a projection type with the storage, causing it to be notified
of relevant events.

=head3 Parameters

=head4 C<Mu:U $type> — The projection type to register

=end pod

method register(Mu:U $type) {
	$.sourcing-projection-storage-projection-registered: :$type
}

=begin pod

=head2 multi method apply

Applies an event to all registered projections that handle this event type.
Creates or updates projections based on the event's identity attributes.

=head3 Parameters

=head4 C<Any $event> — The event to apply to matching projections

=end pod

multi method apply(Any $event) {
	my @regs = %!registries{$event.^name};
	for @regs -> Registry (:$type, :$name, :%map, :@ids) {
		my @id-mapped = %map{|@ids};
		my @id-values = @id-mapped.map: -> $id { $event."$id"() };
		my %id-values = @id-mapped Z[=>] @id-values;
		sourcing $type, |%id-values
	}

}
