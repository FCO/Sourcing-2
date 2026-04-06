use v6.e.PREVIEW;

use Sourcing::Plugin::StateCache;

=begin pod

=head1 NAME

Sourcing::Plugin::StateCache::SQLite - SQLite-based state cache plugin

=head1 DESCRIPTION

A SQLite implementation of L<Sourcing::Plugin::StateCache> that persists
projection state to a SQLite database. This allows projection data to
survive bot restarts.

=end pod

unit class Sourcing::Plugin::StateCache::SQLite;
also does Sourcing::Plugin::StateCache;

has $.db;
has Str $.path;

submethod BUILD(Str :$path = ':memory:') {
	$!path = $path;
	$!db = DBIish.connect('SQLite', :database($path));
	$!db.do(q:to/SQL/);
		CREATE TABLE IF NOT EXISTS projection_cache (
			projection_type TEXT NOT NULL,
			id_key TEXT NOT NULL,
			data TEXT NOT NULL,
			last_id INTEGER NOT NULL,
			updated_at TEXT NOT NULL,
			PRIMARY KEY (projection_type, id_key)
		)
	SQL
}

multi method store-cached-data($proj where *.HOW.^can("data-to-store"), UInt :$last-id!) {
	$.store-cached-data: $proj, $proj.^projection-id-pairs, $proj.^data-to-store, :$last-id
}

multi method store-cached-data($proj, Int :$last-id!) {
	my %data = do for $proj.^attributes.grep({ .has_accessor }) -> $attr {
		$attr.name.substr(2) => $attr.get_value: $proj
	}
	$.store-cached-data: $proj.WHAT, $proj.^projection-id-pairs, %data, :$last-id
}

multi method store-cached-data(Mu:U $proj, %ids, %data, Int :$last-id!) {
	my $id-key = %ids.sort.map({.key ~ "\t" ~ .value}).join(";");
	my $type-name = $proj.^name;
	my $data-json = Rakudo::Internals::JSON.stringify: %data;
	my $now = DateTime.now.Str;
	
	$!db.execute: q:to/SQL/, $type-name, $id-key, $data-json, $last-id, $now;
		INSERT OR REPLACE INTO projection_cache (projection_type, id_key, data, last_id, updated_at)
		VALUES (?, ?, ?, ?, ?)
	SQL
}

method get-cached-data(Mu:U $proj, %ids) is rw {
	my $id-key = %ids.sort.map({.key ~ "\t" ~ .value}).join(";");
	my $type-name = $proj.^name;
	
	my $result = $!db.execute: $type-name, $id-key;
	
	my %return = last-id => -1, data => %();
	if $result {
		my $row = $result[0];
		my $data-json = $row[2];
		my $last-id = $row[3];
		%return<last-id> = $last-id;
		%return<data> = Rakudo::Internals::JSON.parse: $data-json;
	}
	%return
}

method disconnect() {
	$!db.dispose if $!db;
}
