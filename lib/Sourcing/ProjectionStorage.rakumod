use v6.e.PREVIEW;
use Sourcing;
use Sourcing::Projection;

unit aggregation Sourcing::ProjectionStorage;

my class ProjectionRegistered {
	has Mu:U $.type;
	has Str  $.name    = $!type.^name;
	has Str  @.ids     = $!type.^projection-id-names;
	has Hash %.map{Mu} = $!type.^handled-events-map;
}

my class Registry {
	has Str  $.name;
	has Mu:U $.type;
	has      @.ids;
	has      %.map;
}

has $.id is projection-id = 1;
has %.registries;
has $.supply;

method start {
	$!supply = supply {
		my $s = sourcing self.WHAT;
		whenever $*SourcingConfig.supply -> $event {
			$s.apply: $event
		}
	}
}

multi method apply(ProjectionRegistered (Mu:U :$type, Str :$name, :%map, :@ids)) {
	for %map.kv -> $event, %ids {
		%!registries.push: $event.^name => Registry.new: :$type, :$name, :map(%ids), :@ids
	}
}

method register(Mu:U $type) {
	$.sourcing-projection-storage-projection-registered: :$type
}

multi method apply(Any $event) {
	my @regs = %!registries{$event.^name};
	for @regs -> Registry (:$type, :$name, :%map, :@ids) {
		my @id-mapped = %map{|@ids};
		my @id-values = @id-mapped.map: -> $id { $event."$id"() };
		my %id-values = @id-mapped Z[=>] @id-values;
		sourcing $type, |%id-values
	}

}
