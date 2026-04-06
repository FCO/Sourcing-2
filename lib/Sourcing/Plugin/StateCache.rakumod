use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Plugin::StateCache - Interface for state caching backends

=head1 DESCRIPTION

This role defines the interface that state cache plugins must implement.
State caches handle the storage and retrieval of projection state for
faster recovery and reduced event replay overhead.

=end pod

unit role Sourcing::Plugin::StateCache;

=begin pod

=head1 METHODS

=head2 method store-cached-data

Stores the current state and version of a projection.

=head3 Parameters

=head4 C<Mu:U> — The projection type

=head4 C<%> — Additional data to cache

=end pod

method store-cached-data(Mu:U, %) {...}

=begin pod

=head2 method get-cached-data

Retrieves the cached state and version for a projection.

=head3 Parameters

=head4 C<Mu:U> — The projection type

=head4 C<%> — Identity criteria

=head3 Returns

A hash containing C<last-id> and C<data> for the projection.

=end pod

method get-cached-data(Mu:U, %)   {...}

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