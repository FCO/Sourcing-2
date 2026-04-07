use v6.e.PREVIEW;

use DBIish;
use Sourcing::Aggregation;
use Sourcing::Plugin::EventStore;
use Sourcing::X::OptimisticLocked;

=begin pod

=head1 NAME

Sourcing::Plugin::EventStore::SQLite - SQLite-based event storage plugin

=head1 DESCRIPTION

A persistent event storage implementation using SQLite. Events are stored
in a SQLite database with their type, ids, data, and timestamp.

=end pod

unit class Sourcing::Plugin::EventStore::SQLite;
also does Sourcing::Plugin::EventStore;

has Str $.database-path = ':memory:';
has $.dbh is rw;
has Supplier $.supplier .= new;
has Supply() $.supply = $!supplier;
has atomicint $.event-id = -1;

submethod TWEAK(|) {
	$!dbh = DBIish.connect('SQLite', :database($!database-path));
	$!dbh.execute(q:to/STATEMENT/);
		CREATE TABLE IF NOT EXISTS events (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			type TEXT NOT NULL,
			ids TEXT,
			data TEXT NOT NULL,
			timestamp TEXT NOT NULL
		)
		STATEMENT

	$!dbh.execute(q:to/STATEMENT/);
		CREATE INDEX IF NOT EXISTS idx_events_type_ids
		ON events(type, ids)
		STATEMENT

	# Load existing events and emit them to the supply
	my $sth = $!dbh.execute('SELECT id, type, ids, data, timestamp FROM events ORDER BY id');
	while my $row = $sth.row(:hash) {
	$!event-id = $row<id>;
		my $event = self!deserialize-event($row<type>, $row<data>);
		$!supplier.emit: $event;
	}
}

=begin pod

=head2 method !deserialize-event

Deserializes an event from its type and data representation.

=head3 Parameters

=head4 C<Str $type> — The event type name

=head4 C<Str $data> — The serialized event data

=head3 Returns

The deserialized event object.

=end pod

method !deserialize-event(Str $type, Str $data) {
	my $event-type = ::($type);
	my %data-from-json = Rakudo::Internals::JSON.from-json($data);
	$event-type.new(|%data-from-json);
}

=begin pod

=head2 method !serialize-event

Serializes an event to its type name and JSON data representation.

=head3 Parameters

=head4 C<$event> — The event to serialize

=head3 Returns

A list of (type name, serialized data).

=end pod

method !serialize-event($event) {
	my $type = $event.WHAT.^name;
	my %data-to-serialize = do for $event.^attributes.grep({ .has_accessor }) -> $attr {
		$attr.name.substr(2) => $attr.get_value($event)
	}
	my $data = Rakudo::Internals::JSON.to-json(%data-to-serialize);
	($type, $data);
}

=begin pod

=head2 multi method emit

Basic event emission without optimistic locking. Simply emits the event
to the supplier for distribution and persists it to SQLite.

=head3 Parameters

=head4 C<$event> — The event to emit

=end pod

multi method emit($event) {
	my ($type, $data) = self!serialize-event($event);
	my $timestamp = DateTime.now.utc.Str;
	$!dbh.execute(
		'INSERT INTO events (type, ids, data, timestamp) VALUES (?, ?, ?, ?)',
		$type, '', $data, $timestamp
	);
	my $sth = $!dbh.prepare('SELECT last_insert_rowid()');
	$sth.execute;
	my $id = $sth.allrows()[0][0];
	$!event-id = $id;
	$!supplier.emit: $event
}

=begin pod

=head2 multi method emit

Event emission with optimistic locking support. Validates the current
version before emitting to detect concurrent modifications.

=head3 Parameters

=head4 C<$event> — The event to emit

=head4 C<:$type> — The aggregate type

=head4 C<:%ids> — Identity attributes for the aggregate

=head4 C<:$current-version> — Expected current version for optimistic locking

=end pod

multi method emit($event, :$type, :%ids!, :$current-version!) {
	unless $type ~~ Sourcing::Aggregation {
		die "Only aggregations can emit events. Projections are read-only.";
	}

	my $key = $type.WHAT.^name;
	my $id-key = %ids.sort.map({ .key ~ "\t" ~ .value }).join(";");

	# Get the current max version for this aggregate
	my $sth = $!dbh.execute(
		'SELECT MAX(CAST(id AS INTEGER)) as max_id FROM events WHERE type = ? AND ids = ?',
		$key, $id-key
	);
	my $row = $sth.row(:hash);
	my $stored-version //= -1;
	$stored-version = $row<max-id> // -1;

	my $new-version = $current-version + 1;
	if $stored-version != $current-version {
		Sourcing::X::OptimisticLocked.new(
			:type($type),
			:ids(%ids),
			:expected-version($current-version),
			:actual-version($stored-version)
		).throw
	}

	my ($evt-type, $data) = self!serialize-event($event);
	my $timestamp = DateTime.now.utc.Str;
	$!dbh.execute(
		'INSERT INTO events (type, ids, data, timestamp) VALUES (?, ?, ?, ?)',
		$evt-type, $id-key, $data, $timestamp
	);
	my $id = do { my $s = $!dbh.prepare('SELECT last_insert_rowid()'); $s.execute; $s.allrows()[0][0] };
	$!event-id = $id;
	$!supplier.emit: $event
}

=begin pod

=head2 sub get-events

Filter function that selects events matching the given identity criteria.

=head3 Parameters

=head4 C<@events> — The list of events to filter

=head4 C<%ids> — Identity attribute names and values to match

=head4 C<%map> — Event type to identity attribute mapping

=head3 Returns

Filtered list of matching events.

=end pod

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

=begin pod

=head2 method get-events

Retrieves all stored events matching the given criteria.

=head3 Parameters

=head4 C<%ids> — Identity criteria

=head4 C<%map> — Event type mapping

=head3 Returns

Filtered list of events from the database.

=end pod

method get-events(%ids, %map) {
	my $events = self!fetch-events(%ids, %map);
	$events.&get-events: %ids, %map
}

=begin pod

=head2 method !fetch-events

Fetches events from the database that match the given criteria.

=head3 Parameters

=head4 C<%ids> — Identity criteria

=head4 C<%map> — Event type mapping

=head3 Returns

List of event objects.

=end pod

method !fetch-events(%ids, %map) {
	my @events;
	my @types = %map.keys.map({ .^name });

	if @types.elems == 0 {
		return @events;
	}

	my $placeholders = @types.map({ '?' }).join(',');
	my $query = "SELECT type, ids, data, timestamp FROM events WHERE type IN ($placeholders) ORDER BY id";

	my $sth = $!dbh.execute($query, |@types);
	while my $row = $sth.row(:hash) {
		my $event = self!deserialize-event($row<type>, $row<data>);
		@events.push: $event;
	}

	@events
}

=begin pod

=head2 method get-events-after

Retrieves events after a specific version, suitable for catching up
projections to the current state.

=head3 Parameters

=head4 C<Int $id> — The version ID to get events after

=head4 C<%ids> — Identity criteria

=head4 C<%map> — Event type mapping

=head3 Returns

Sequence of events after the given version.

=end pod

method get-events-after(Int $id, %ids, %map) {
	my @events = self!fetch-events(%ids, %map);
	@events.&get-events(%ids, %map).skip: $id + 1
}

=begin pod

=head2 method number-of-events

Returns the total number of events stored.

=head3 Returns

The count of events in the store.

=end pod

method number-of-events {
	my $sth = $!dbh.execute('SELECT COUNT(*) as cnt FROM events');
	my $row = $sth.row(:hash);
	$row<cnt> // 0
}

=begin pod

=head2 method disconnect

Closes the database connection.

=end pod

method disconnect {
	$!dbh.dispose if $!dbh;
}

=begin pod

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
	$!dbh.execute(q:to/STATEMENT/);
		CREATE TABLE IF NOT EXISTS projection_cache (
			projection_type TEXT NOT NULL,
			id_key TEXT NOT NULL,
			data TEXT NOT NULL,
			last_id INTEGER NOT NULL,
			PRIMARY KEY (projection_type, id_key)
		)
		STATEMENT

	my $id-key = %ids.sort.map({ .key ~ "\t" ~ .value }).join(";");
	my $data-json = Rakudo::Internals::JSON.to-json(%data);

	my $stmt = $!dbh.prepare('INSERT OR REPLACE INTO projection_cache (projection_type, id_key, data, last_id) VALUES (?, ?, ?, ?)');
	$stmt.execute($proj.^name, $id-key, $data-json, $last-id);
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
	$!dbh.execute(q:to/STATEMENT/);
		CREATE TABLE IF NOT EXISTS projection_cache (
			projection_type TEXT NOT NULL,
			id_key TEXT NOT NULL,
			data TEXT NOT NULL,
			last_id INTEGER NOT NULL,
			PRIMARY KEY (projection_type, id_key)
		)
		STATEMENT

	my $id-key = %ids.sort.map({ .key ~ "\t" ~ .value }).join(";");

	my $sth = $!dbh.execute(
		'SELECT data, last_id FROM projection_cache WHERE projection_type = ? AND id_key = ?',
		$proj.^name, $id-key
	);

	my $row = $sth.row(:hash);
	if $row {
		my %data = Rakudo::Internals::JSON.from-json($row<data>);
		my $last-id = $row<last-id> // -1;
		return %( data => %data, last-id => $last-id );
	} else {
		return %( data => %(), last-id => -1 );
	}
}
