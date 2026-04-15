use v6.e.PREVIEW;

use Sourcing::Aggregation;
use Sourcing::Plugin::EventStore;
use Sourcing::X::OptimisticLocked;

=begin pod

=head1 NAME

Sourcing::Plugin::EventStore::Memory - In-memory event storage plugin

=head1 DESCRIPTION

A simple in-memory implementation of L<Sourcing::Plugin::EventStore> for development
and testing. Events are stored in memory and a supply emits them in order.

=end pod

unit class Sourcing::Plugin::EventStore::Memory;
also does Sourcing::Plugin::EventStore;

sub id-key(Mu:U $proj, %ids) {
	my @projection-id-names = $proj.^projection-id-names;
	@projection-id-names.map({ %ids{$_}.Str }).join("\t")
}

has Supplier $.supplier .= new;
has Supply() $.supply    = $!supplier;
has @.events;
has @!stored-events;
has Int $!event-id = -1;
has %.store;
has %.stream-versions;

=begin pod

=head1 METHODS

=head2 submethod TWEAK

Initializes the supplier tap to capture events as they are emitted.

=end pod

submethod TWEAK(|) {
	$!supply.tap: -> $event { @!events.push: $event }
}

=begin pod

=head2 multi method emit

Basic event emission without optimistic locking. Simply emits the event
to the supplier for distribution.

=head3 Parameters

=head4 C<$event> — The event to emit

=end pod

multi method emit($event) {
	my $event-id = ++$!event-id;
	@!stored-events.push: %(
		id             => $event-id,
		event          => $event,
		aggregate-type => '',
		projection-ids => [],
		stream-version => Nil,
		metadata       => %(),
	);
	$!supplier.emit: $event
}

=begin pod

=head2 multi method emit

Event emission with optimistic locking support. Validates the current
version before emitting to detect concurrent modifications.

=head3 Parameters

=head4 C<$event> — The event to emit

=head4 C<:$type> — The aggregate type

=head4 C<:%ids> — Identity attributes for the aggregate

=head4 C<:$current-version> — Expected current version for optimistic locking

=end pod

multi method emit($event, :$type, :%ids!, :$current-version!) {
	unless $type ~~ Sourcing::Aggregation {
		die "Only aggregations can emit events. Projections are read-only.";
	}
	my $new-version = $current-version + 1;
	my @projection-id-names = $type.^projection-id-names;
	my @projection-ids = @projection-id-names.map: -> $name { %ids{$name} };
	my $stream-key = $type.^name ~ "\t" ~ @projection-ids.map(*.Str).join("\t");
	my $stored-version = %!stream-versions{$stream-key} // -1;
	unless $stored-version == $current-version {
		Sourcing::X::OptimisticLocked.new(
			:type($type),
			:ids(%ids),
			:expected-version($current-version),
			:actual-version($stored-version)
		).throw
	}
	%!stream-versions{$stream-key} = $new-version;
	my $event-id = ++$!event-id;
	@!stored-events.push: %(
		id             => $event-id,
		event          => $event,
		aggregate-type => $type.^name,
		projection-ids => @projection-ids.Array,
		stream-version => $new-version,
		metadata       => %(),
	);
	my %cached := self.get-cached-data($type, %ids);
	%cached<last-id> = $event-id;
	$!supplier.emit: $event
}

=begin pod

=head2 sub get-events

Filter function that selects events matching the given identity criteria.

=head3 Parameters

=head4 C<@events> — The list of events to filter

=head4 C<%ids> — Identity attribute names and values to match

=head4 C<%map> — Event type to identity attribute mapping

=head3 Returns

Filtered list of matching events.

=end pod

sub get-events(@event-records, %ids, %map) {
	@event-records.grep: -> %record {
		my $event = %record<event>;
		next unless $event.WHAT ~~ %map.keys.any;
		my $event-type = $event.WHAT;
		my %event-map := %map{$event-type};
		[&&] do for %ids.kv -> $key, $value {
			my $event-key = %event-map{$key};
			$event."$event-key"() ~~ $value
		}
	}.map(*<event>)
}

=begin pod

=head2 method get-events

Retrieves all stored events matching the given criteria.

=head3 Parameters

=head4 C<%ids> — Identity criteria

=head4 C<%map> — Event type mapping

=head3 Returns

Filtered list of events from the internal store.

=end pod

method get-events(%ids, %map) {
	@!stored-events.&get-events: %ids, %map
}

=begin pod

=head2 method get-events-after

Retrieves events after a specific version, suitable for catching up
projections to the current state.

=head3 Parameters

=head4 C<Int $id> — The version ID to get events after

=head4 C<%ids> — Identity criteria

=head4 C<%map> — Event type mapping

=head3 Returns

Sequence of events after the given version.

=end pod

method get-events-after(Int $id, %ids, %map) {
	@!stored-events
		.grep(*<id> > $id)
		.&get-events(%ids, %map)
}

=begin pod

=head2 method number-of-events

Returns the total number of events stored.

=head3 Returns

The count of events in the store.

=end pod

method number-of-events { @!events.elems }

=begin pod

=head2 multi method store-cached-data

Stores projection state using the projection's built-in serialization method.

=head3 Parameters

=head4 C<$proj> — The projection instance

=head4 C<:UInt :$last-id> — The last processed event version

=end pod

multi method store-cached-data($proj where *.HOW.^can("data-to-store"), UInt :$last-id!) {
	$.store-cached-data: $proj, $proj.^projection-id-pairs, $proj.^data-to-store, :$last-id
}

=begin pod

=head2 multi method store-cached-data

Stores projection state by extracting attribute values from the instance.

=head3 Parameters

=head4 C<$proj> — The projection instance

=head4 C<Int :$last-id> — The last processed event version

=end pod

multi method store-cached-data($proj, Int :$last-id!) {
	my %data = do for $proj.^attributes.grep({ .has_accessor }) -> $attr {
		$attr.name.substr(2) => $attr.get_value: $proj
	}
	$.store-cached-data: $proj.WHAT, $proj.^projection-id-pairs, %data, :$last-id
}

=begin pod

=head2 multi method store-cached-data

Low-level method to store projection data under a specific key.

=head3 Parameters

=head4 C<Mu:U $proj> — The projection type

=head4 C<%ids> — Identity attribute values

=head4 C<%data> — State data to store

=head4 C<Int :$last-id> — The last processed event version

=end pod

multi method store-cached-data(Mu:U $proj, %ids, %data, Int :$last-id!) {
	my $id-key = id-key($proj, %ids);
	%!store{$proj.^name}:exists || (%!store{$proj.^name} = Hash.new);
	%!store{$proj.^name}{$id-key}<data> = %data;
	%!store{$proj.^name}{$id-key}<last-id> = $last-id;
}

=begin pod

=head2 method get-cached-data

Retrieves the cached state and version for a projection instance.

=head3 Parameters

=head4 C<Mu:U $proj> — The projection type

=head4 C<%ids> — Identity attribute values

=head3 Returns

A hash containing C<last-id> and C<data> for the projection.

=end pod

method get-cached-data(Mu:U $proj, %ids) is rw {
	my $id-key = id-key($proj, %ids);
	%!store{$proj.^name}:exists || (%!store{$proj.^name} = Hash.new);
	%!store{$proj.^name}{$id-key}:exists || (%!store{$proj.^name}{$id-key} = Hash.new);
	my atomicint $last-id = -1;
	%!store{$proj.^name}{$id-key}<last-id> //= $last-id;
	%!store{$proj.^name}{$id-key}<data> //= %();
	%!store{$proj.^name}{$id-key}
}
