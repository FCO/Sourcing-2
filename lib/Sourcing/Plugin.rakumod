use v6.e.PREVIEW;

use Sourcing::Plugin::EventStore;
use Sourcing::Plugin::StateCache;

=begin pod

=head1 NAME

Sourcing::Plugin - Interface for event sourcing storage backends

=head1 DESCRIPTION

This role defines the interface that storage plugins must implement. Plugins
handle event persistence, retrieval, and the supply of events for projections.

=head1 NOTE

This role combines L<Sourcing::Plugin::EventStore> and L<Sourcing::Plugin::StateCache>
for backward compatibility. New code should use the separate roles for more flexibility.

=end pod

unit role Sourcing::Plugin;

# Re-export EventStore methods (with default implementations for backward compatibility)
method emit($, :$current-version) { ... }
method get-events(%ids, %map) { ... }
method get-events-after($, %, %) { ... }
method supply { ... }

# Re-export StateCache methods (with default implementations for backward compatibility)
method store-cached-data(Mu:U, %) { ... }
method get-cached-data(Mu:U, %) { ... }

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