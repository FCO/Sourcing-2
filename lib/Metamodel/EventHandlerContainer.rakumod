unit role Metamodel::EventHandlerContainer;

has $!events-handled-by;
has $!events-handled-map;
has $!events-handled-reverse-map;

sub applies(Mu $proj) {
	my $apply = $proj.^find_method: "apply";
	die "A method `apply` is required for `{$proj.^name}`" unless $apply;
	$apply.candidates
}

method handled-events(Mu $proj --> Array()) {
	$!events-handled-by //= do for applies $proj -> &candidate {
		my $param = &candidate.signature.params.skip.head;
		next if $param.named;
		$param.type
	}
}

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
