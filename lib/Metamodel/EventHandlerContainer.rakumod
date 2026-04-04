=begin pod

=head1 NAME

Metamodel::EventHandlerContainer - Metaclass role for event handling

=head1 DESCRIPTION

This role is composed into the projection metaclass to track which event types
a projection handles and to build maps for correlating events with projections.

=end pod

unit role Metamodel::EventHandlerContainer;

has $!events-handled-by;
has $!events-handled-map;

=begin pod

=head1 FUNCTIONS

=head2 sub applies

Internal helper that finds the C<apply> method candidates on a projection
class. Each candidate represents a different event type that can be applied.

=head3 Parameters

=head4 C<Mu $proj> — The projection class

=head3 Returns

The candidates of the C<apply> method.

=head3 Dies

If no C<apply> method is found.

=end pod

sub applies(Mu $proj) {
	my $apply = $proj.^find_method: "apply";
	die "A method `apply` is required for `{$proj.^name}`" unless $apply;
	$apply.candidates
}

=begin pod

=head1 METHODS

=head2 method handled-events

Returns all event types that this projection can handle, extracted from
the C<apply> method signatures.

=head3 Parameters

=head4 C<Mu $proj> — The projection class

=head3 Returns

An L<Array> of event type objects.

=end pod

method handled-events(Mu $proj --> Array()) {
	$!events-handled-by //= do for applies $proj -> &candidate {
		my $param = &candidate.signature.params.skip.head;
		next if $param.named;
		$param.type
	}
}

=begin pod

=head2 method handled-events-map

Builds a map from event types to their projection ID attribute mappings.
This is used to correlate events with specific projection instances.

=head3 Parameters

=head4 C<Mu $proj> — The projection class

=head3 Returns

A hash mapping event types to their identity attribute mappings.

=end pod

method handled-events-map(Mu $proj) {
	$!events-handled-map //= Hash[Mu, Mu].new: do for applies $proj -> &candidate {
		my $param = &candidate.signature.params.skip.head;
		next if $param.named;

		my %map := &candidate.?projection-id-map // %();
		my %funcs = %map.kv.map: -> $k, $v {
			$k => $v
		}
		$param.type => %(
			|$proj.^projection-ids.map: -> $attr {
				my $method = $attr.name.substr: 2;
				$method => %funcs{$method} // $method
			}
		)
	}
}
