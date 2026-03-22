unit role Sourcing::Plugin;

method emit($, :$current-version) {...}
method get-events(%ids, %map)     {...}
method get-events-after($, %, %)  {...}
method supply                     {...}
method store-cached-data(Mu:U, %) {...}
method get-cached-data(Mu:U, %)   {...}
# method number-of-events           {...}

method use(|c) {
	PROCESS::<$SourcingConfig> = self.new: |c;
}
