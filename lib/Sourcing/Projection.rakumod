unit role Sourcing::Projection;

has $!__current-verion__;

multi method new(:@initial-events!, |c) {
	my $obj = self.bless: |c;
	for @initial-events -> $event {
		$obj.apply: $_ with $event;
	}
	$obj
}
