unit role Metamodel::ProjectionIdContainer;
use Sourcing::ProjectionId;

has @!projection-ids;

multi method compose-projection-id(Mu $proj) {
	for $proj.^attributes.grep: Sourcing::ProjectionId {
		@!projection-ids.push: .clone
	}
}

method projection-ids(|)      { @!projection-ids }
method projection-id-names(|) { @!projection-ids.map: *.name.substr: 2 }
method projection-id-pairs($proj --> Map()) {
	@!projection-ids.map: {
		my $name = .name.substr: 2;
		$name => $proj."$name"()
	}
}
