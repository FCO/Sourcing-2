use Sourcing::Plugin;
# use Sourcing::X::OptmisticLocked;
unit class Sourcing::Plugin::Memory;
also does Sourcing::Plugin;

has Supplier $.supplier .= new;
has Supply() $.supply    = $!supplier;
has @.events;
has %.store;

submethod TWEAK(|) {
	$!supply.tap: -> $event { @!events.push: $event }
}

multi method emit($event) {
	$!supplier.emit: $event
}

# TODO: Make use of cas
multi method emit($event, :$type, :%ids!, :$current-version!) {
	my :(atomicint :$last-id!, |) := $.get-cached-data: $type.WHAT, %ids;
	# my :(atomicint :$last-id! is rw, |) := $.get-cached-data: $type.WHAT, %ids;
	# unless cas $last-id, $current-version, $current-version + 1 {
	# 	Sourcing::X::OptmisticLocked.new.throw
	# }
	$.emit: $event
}

sub get-events(@events, %ids, %map) {
	@events.grep: -> $event {
		next unless $event.WHAT ~~ %map.keys.any;
		my $event-type = $event.WHAT;
		do if %map{$event-type} {
			my %event-map := %map{$event-type};
			[&&] do for %ids.kv -> $key, $value {
				my $event-key = %event-map{$key};
				$event."$event-key"() ~~ $value
			}
		} else {
			True
		}
	}
}

method get-events(%ids, %map) {
	@!events.&get-events: %ids, %map
}

method get-events-after(Int $id, %ids, %map) {
	@!events.&get-events(%ids, %map).skip: $id + 1
}

method number-of-events { @!events.elems }

# TODO: Make use of cas
multi method store-cached-data($proj where *.HOW.^can("data-to-store"), UInt :$last-id!) {
	$.store-cached-data: $proj, $proj.^projection-id-pairs, $proj.^data-to-store, :$last-id
}

# TODO: Make use of cas
multi method store-cached-data($proj, Int :$last-id!) {
	my %data = do for $proj.^attributes.grep({ .has_accessor }) -> $attr {
		$attr.name.substr(2) => $attr.get_value: $proj
	}
	$.store-cached-data: $proj.WHAT, $proj.^projection-id-pairs, %data, :$last-id
}

# TODO: Make use of cas
multi method store-cached-data(Mu:U $proj, %ids, %data, Int :$last-id!) {
	my %final := Map.new: (data => %data, last-id => $last-id);
	%!store{$proj.^name} := Map.new: (|(%!store{$proj.^name} // %()), $%ids => %final)
}

method get-cached-data(Mu:U $proj, %ids) is rw {
	my atomicint $last-id = -1;
	%!store{$proj.^name}{$%ids} // { :$last-id, data => %() };
}
