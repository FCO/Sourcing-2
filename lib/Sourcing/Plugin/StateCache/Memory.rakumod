use v6.e.PREVIEW;

use Sourcing::Plugin::StateCache;

=begin pod

=head1 NAME

Sourcing::Plugin::StateCache::Memory - In-memory state cache plugin

=head1 DESCRIPTION

A simple in-memory implementation of L<Sourcing::Plugin::StateCache> for development
and testing. Projection state is cached in memory for fast retrieval.

=end pod

unit class Sourcing::Plugin::StateCache::Memory;
also does Sourcing::Plugin::StateCache;

sub id-key(Mu:U $proj, %ids) {
	my @projection-id-names = $proj.^projection-id-names;
	@projection-id-names.map({ %ids{$_}.Str }).join("\t")
}

has %.store;

=begin pod

=head1 METHODS

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
