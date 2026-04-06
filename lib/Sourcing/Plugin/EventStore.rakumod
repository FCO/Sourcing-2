use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Plugin::EventStore - Interface for event storage backends

=head1 DESCRIPTION

This role defines the interface that event store plugins must implement.
Event stores handle event persistence, retrieval, and the supply of events
for projections.

=end pod

unit role Sourcing::Plugin::EventStore;

=begin pod

=head1 METHODS

=head2 method emit

Emits an event to the storage backend. Concrete implementations should
handle persistence and notification of the event supply.

=head3 Parameters

=head4 C<$> — The event to emit

=head4 C<:$current-version> — The current version of the aggregate (optional)

=end pod

method emit($, :$current-version) {...}

=begin pod

=head2 method get-events

Retrieves all events that match the given identity criteria.

=head3 Parameters

=head4 C<%ids> — Hash of identity attribute names to values

=head4 C<%map> — Hash mapping event types to their identity mappings

=head3 Returns

A list or sequence of matching events.

=end pod

method get-events(%ids, %map)     {...}

=begin pod

=head2 method get-events-after

Retrieves events that occurred after the specified version.

=head3 Parameters

=head4 C<$> — The version/ID to get events after

=head4 C<%> — Additional filtering criteria

=head4 C<%> — Event mapping configuration

=head3 Returns

A sequence of events after the given version.

=end pod

method get-events-after($, %, %)  {...}

=begin pod

=head2 method supply

Returns a L<Supply> of events from this storage backend.

=head3 Returns

A L<Supply> that emits events as they are stored.

=end pod

method supply                     {...}

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