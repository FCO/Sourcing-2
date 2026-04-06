use v6.e.PREVIEW;

use Sourcing::Plugin::EventStore;
use Sourcing::Plugin::EventStore::Memory;
use Sourcing::Plugin::StateCache;
use Sourcing::Plugin::StateCache::Memory;

=begin pod

=head1 NAME

Sourcing::Plugin::Memory - In-memory event storage and state cache plugin

=head1 DESCRIPTION

A simple in-memory implementation of L<Sourcing::Plugin> for development
and testing. This class combines L<Sourcing::Plugin::EventStore::Memory>
and L<Sourcing::Plugin::StateCache::Memory> for backward compatibility.

For new code, you can use the separate roles:
=item L<Sourcing::Plugin::EventStore::Memory> for event storage
=item L<Sourcing::Plugin::StateCache::Memory> for state caching

=end pod

unit class Sourcing::Plugin::Memory;
also does Sourcing::Plugin::EventStore;
also does Sourcing::Plugin::StateCache;

has Sourcing::Plugin::EventStore::Memory $.event-store .= new;
has Sourcing::Plugin::StateCache::Memory $.state-cache .= new;

=begin pod

=head1 METHODS

=head2 method emit

Emits an event to the storage backend.

=head3 Parameters

=head4 C<$event> — The event to emit

=head4 C<:$current-version> — The current version of the aggregate (optional)

=end pod

method emit($event, |c) {
	$!event-store.emit: $event, |c
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
	$!event-store.get-events: %ids, %map
}

=begin pod

=head2 method get-events-after

Retrieves events after a specific version.

=head3 Parameters

=head4 C<Int $id> — The version ID to get events after

=head4 C<%ids> — Identity criteria

=head4 C<%map> — Event type mapping

=head3 Returns

Sequence of events after the given version.

=end pod

method get-events-after(Int $id, %ids, %map) {
	$!event-store.get-events-after: $id, %ids, %map
}

=begin pod

=head2 method supply

Returns a L<Supply> of events from this storage backend.

=head3 Returns

A L<Supply> that emits events as they are stored.

=end pod

method supply {
	$!event-store.supply
}

=begin pod

=head2 method events

Returns the list of stored events.

=head3 Returns

The list of events.

=end pod

method events {
	$!event-store.events
}

=begin pod

=head2 multi method store-cached-data

Stores projection state using the projection's built-in serialization method.

=head3 Parameters

=head4 C<$proj> — The projection instance

=head4 C<:UInt :$last-id> — The last processed event version

=end pod

multi method store-cached-data($proj where *.HOW.^can("data-to-store"), UInt :$last-id!) {
	$!event-store.store-cached-data: $proj, :$last-id
}

=begin pod

=head2 multi method store-cached-data

Stores projection state by extracting attribute values from the instance.

=head3 Parameters

=head4 C<$proj> — The projection instance

=head4 C<Int :$last-id> — The last processed event version

=end pod

multi method store-cached-data($proj, Int :$last-id!) {
	$!event-store.store-cached-data: $proj, :$last-id
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
	$!event-store.store-cached-data: $proj, %ids, %data, :$last-id
}

=begin pod

=head2 method get-cached-data

Retrieves the cached state and version for a projection.

=head3 Parameters

=head4 C<Mu:U $proj> — The projection type

=head4 C<%ids> — Identity criteria

=head3 Returns

A hash containing C<last-id> and C<data> for the projection.

=end pod

method get-cached-data(Mu:U $proj, %ids) is rw {
	$!event-store.get-cached-data: $proj, %ids
}

=begin pod

=head2 method number-of-events

Returns the total number of events stored.

=head3 Returns

The count of events in the store.

=end pod

method number-of-events {
	$!event-store.number-of-events
}

=begin pod

=head2 method use

Activates this plugin as the current sourcing configuration by
setting the C<PROCESS> variable.

=head3 Parameters

=head4 C<|c> — Configuration arguments passed to the plugin constructor

=end pod

method use(|c) {
	PROCESS::<$SourcingConfig> = self.new: |c;
}