# Sourcing Library Specification

Sourcing is a Raku (Perl 6) event sourcing library that provides a declarative approach to building projections and aggregations using metaclasses, roles, and custom traits.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core API Reference](#core-api-reference)
4. [Metamodel Classes](#metamodel-classes)
5. [Plugin System](#plugin-system)
6. [Traits and Declarations](#traits-and-declarations)
7. [Storage System](#storage-system)
8. [Usage Patterns](#usage-patterns)

---

## Overview

Event sourcing is a pattern where state changes are stored as a sequence of events rather than updating current state directly. The Sourcing library provides:

- **Projections**: Read-only representations that evolve by applying events
- **Aggregations**: Stateful entities that can both handle and emit events
- **Declarative ID mapping**: Map event properties to projection identifiers
- **Plugin architecture**: Pluggable event storage backends

### Key Design Decisions

1. **Metaclass-based**: Uses custom metaclasses (`ProjectionHOW`, `AggregationHOW`) that inherit from `Metamodel::ClassHOW` to add introspection capabilities
2. **Role-based composition**: Composes functionality through roles (`Sourcing::Projection`, `Sourcing::Aggregation`)
3. **Trait-driven**: Uses Raku's trait system (`trait_mod:<is>`) for declarative configuration
4. **Supply-based**: Uses Raku's `Supply` for event streaming

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Sourcing.rakumod                         │
│  (exports: sourcing, traits, EXPORTHOW/DECLARE for metaclasses)│
└─────────────────────────────────────────────────────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────┐      ┌─────────────────┐
│  Roles/         │      │  Metamodel/      │
│  - Projection   │      │  - ProjectionHOW │
│  - Aggregation  │      │  - AggregationHOW
│  - ProjectionId │      │  - ProjectionIdContainer
│  - ProjectionIdMap │   │  - EventHandlerContainer
└─────────────────┘      └─────────────────┘
         │
         ▼
┌─────────────────┐
│  Sourcing::    │
│  - Plugin       │
│  - Plugin::Memory│
│  - ProjectionStorage │
│  - X::OptimisticLocked│
└─────────────────┘
```

---

## Core API Reference

### Sourcing.rakumod

**Purpose**: Main entry point for the library. Exports the `sourcing` function and all custom traits.

**Exports**:

| Symbol | Type | Description |
|--------|------|-------------|
| `sourcing` | Sub | Creates or retrieves a projection/aggregation instance |
| `projection` | Constant | Metaclass declaration for projections |
| `aggregation` | Constant | Metaclass declaration for aggregations |
| `is projection-id` | Trait | Marks attribute as projection identifier |
| `is projection-id-map` | Trait | Maps apply method to custom ID field |
| `is projection-id<>` | Trait | Shorthand for single ID mapping |
| `is command` | Trait | Wraps method to trigger `^update` after call |

**Public API**:

```raku
sub sourcing(Sourcing::Projection:U $proj, *%ids) is export
# Creates or retrieves a projection instance with given IDs
# - $proj: The projection/aggregation class
# - %ids: Named parameters for projection ID values
# Returns: Instance with initial events applied

sub sourcing-config is rw is export
# Global configuration accessor (PROCESS::<%SourcingConfig>)
```

**Example Usage**:
```raku
use Sourcing;

my $proj = sourcing MyProjection, :id(42);
# Creates/retrieves MyProjection with id=42, applies all events
```

**How it works**:
1. Gets cached data via `$*SourcingConfig.get-cached-data`
2. Retrieves events after last version via `$*SourcingConfig.get-events-after`
3. Creates instance with `initial-events` named parameter
4. Sets `__current-version__` attribute to track last processed event ID
5. Stores updated cached data

---

### Sourcing::Projection

**Purpose**: Role applied to all projection classes via metaclass. Provides event application infrastructure.

**Location**: `lib/Sourcing/Projection.rakumod`

**Attributes**:
```raku
has $!__current-version__;
# Internal version tracking for optimistic concurrency
```

**Public Methods**:
```raku
multi method new(:@initial-events!, |c)
# Creates projection and applies initial events
# - @initial-events: Events to apply on creation
# Returns: New projection instance with events applied
```

**Interactions**:
- Automatically composed into classes using `projection` metaclass
- Provides `apply` method signature that event handlers must match
- Works with `EventHandlerContainer` to discover event types

---

### Sourcing::Aggregation

**Purpose**: Empty role marker that identifies a class as an aggregation (can emit events).

**Location**: `lib/Sourcing/Aggregation.rakumod`

**Note**: This is primarily a marker role. The actual event emission functionality is implemented in `AggregationHOW` metaclass which adds command methods that call `$*SourcingConfig.emit`.

**Interactions**:
- Composed by `AggregationHOW` metaclass
- Inherits from `ProjectionHOW`, so aggregations are also projections

---

### Sourcing::ProjectionId

**Purpose**: Role applied to attributes via the `is projection-id` trait. Marks attributes as projection identifiers.

**Location**: `lib/Sourcing/ProjectionId.rakumod`

**Public Methods**:
```raku
method is-projection-id { True }
# Returns True to identify this as a projection ID attribute
```

**Interactions**:
- Applied via `trait_mod:<is>(Attribute $r, Bool :$projection-id)`
- Discovered by `ProjectionIdContainer` during composition

---

### Sourcing::ProjectionIdMap

**Purpose**: Role applied to methods to store custom ID mapping configuration.

**Location**: `lib/Sourcing/ProjectionIdMap.rakumod`

**Attributes**:
```raku
has Str %.projection-id-map{Str};
# Maps projection ID names to event field names
```

**Public Methods**:
```raku
method projection-id-map { %!projection-id-map }
# Returns the mapping hash
```

**Interactions**:
- Applied via `is projection-id-map` or `is projection-id<>` traits
- Used by `EventHandlerContainer` when building event handlers

---

## Metamodel Classes

### Metamodel::ProjectionHOW

**Purpose**: Metaclass for projection classes. Inherits from `Metamodel::ClassHOW` and composes the `Sourcing::Projection` role.

**Location**: `lib/Metamodel/ProjectionHOW.rakumod`

**Public Methods**:
```raku
method compose(Mu $proj, |)
# Composes the projection class:
# 1. Adds Sourcing::Projection role
# 2. Calls compose-projection-id from ProjectionIdContainer
# 3. Calls nextsame for standard composition

method update($proj)
# Applies new events since last version:
# 1. Gets current version from $!__current-version__
# 2. Fetches new events via $*SourcingConfig.get-events-after
# 3. Applies each event via $proj.apply: $event
# 4. Updates version and returns new ID
```

**Introspection Methods** (provided by composed roles):
```raku
$proj.^projection-ids          # Array of projection ID attributes
$proj.^projection-id-names    # Array of ID attribute names (without $!)
$proj.^projection-id-pairs    # Map of ID name to current value
$proj.^handled-events         # Array of event types
$proj.^handled-events-map     # Hash of event type to ID mappings
```

**Interactions**:
- Composes `Metamodel::ProjectionIdContainer` role
- Composes `Metamodel::EventHandlerContainer` role
- Automatically composes `Sourcing::Projection` role into classes

---

### Metamodel::AggregationHOW

**Purpose**: Metaclass for aggregation classes. Extends `ProjectionHOW` and adds automatic command method generation.

**Location**: `lib/Metamodel/AggregationHOW.rakumod`

**Public Methods**:
```raku
method compose(Mu $aggregation, |)
# Composes aggregation:
# 1. Calls parent compose (adds Projection role)
# 2. Adds Sourcing::Aggregation role
# 3. For each handled event type:
#    - Creates lowercase method name (kebab-case)
#    - Method accepts event parameters
#    - Builds event with projection ID values from self
#    - Emits event via $*SourcingConfig.emit
#    - Returns created event
```

**Automatic Command Generation**:
For an event `MyEvent` with projection ID `$!id`:
- Creates method `my-event($value)` 
- Sets `id` field from `$!id` attribute
- Accepts additional named parameters
- Emits event to the supply
- Returns the emitted event

**Interactions**:
- Inherits from `Metamodel::ProjectionHOW`
- Composes `Sourcing::Aggregation` role
- Works with `handled-events-map` to discover events

---

### Metamodel::ProjectionIdContainer

**Purpose**: Role providing projection ID introspection. Composed into `ProjectionHOW`.

**Location**: `lib/Metamodel/ProjectionIdContainer.rakumod`

**Attributes**:
```raku
has @!projection-ids;
# Private array storing projection ID attributes
```

**Public Methods**:
```raku
multi method compose-projection-id(Mu $proj)
# Called during composition to collect projection ID attributes
# Iterates over $proj.^attributes, selects those doing Sourcing::ProjectionId
# Stores them in @!projection-ids

method projection-ids(|)
# Returns array of projection ID attributes

method projection-id-names(|)
# Returns array of ID names without $! prefix

method projection-id-pairs(Mu $proj --> Map())
# Returns Map of ID name to current value for given instance
# Example: Map.new(('id' => 42))
```

---

### Metamodel::EventHandlerContainer

**Purpose**: Role providing event handler introspection. Composed into metaclasses.

**Location**: `lib/Metamodel/EventHandlerContainer.rakumod`

**Attributes**:
```raku
has $!events-handled-by;
has $!events-handled-map;
has $!events-handled-reverse-map;
# Caches for event type introspection
```

**Public Methods**:
```raku
method handled-events(Mu $proj --> Array())
# Returns array of event types handled by apply methods
# Inspects multi candidates of apply method
# Returns types of first positional parameter (after self)

method handled-events-map(Mu $proj)
# Returns Hash mapping event type to ID mapping
# Each entry: EventType => Hash mapping projection ID to event field
# Example: MyEvent => {:id<id>, :name<name>}
```

**How it works**:
1. Finds `apply` method on projection
2. Iterates over multi candidates
3. Extracts first positional parameter type (skips `self`)
4. Checks for `projection-id-map` trait on method
5. Combines with default mappings from projection IDs

---

## Plugin System

### Sourcing::Plugin

**Purpose**: Abstract role defining the interface for event storage backends.

**Location**: `lib/Sourcing/Plugin.rakumod`

**Abstract Methods**:
```raku
method emit($, :$current-version)
# Emit an event to the system
# - $event: The event to emit
# - :$current-version: Optional version for optimistic locking

method get-events(%ids, %map)
# Retrieve events matching IDs and event type map

method get-events-after($, %, %)
# Retrieve events after a given version ID

method supply
# Returns the Supply of events

method store-cached-data(Mu:U, %)
# Store cached state for a projection

method get-cached-data(Mu:U, %)
# Retrieve cached state for a projection
```

**Public Methods**:
```raku
method use(|c)
# Class method to install plugin as global config
# Sets PROCESS::<$SourcingConfig> to plugin instance
# Example: Sourcing::Plugin::Memory.use
```

---

### Sourcing::Plugin::Memory

**Purpose**: In-memory implementation of the Plugin interface. Suitable for testing and development.

**Location**: `lib/Sourcing/Plugin/Memory.rakumod`

**Attributes**:
```raku
has Supplier $.supplier;
has Supply() $.supply;
has @.events;
has %.store;
# Supplier: emits events
# supply: tap that pushes to @.events
# events: all emitted events
# store: cached projection state
```

**Public Methods**:
```raku
multi method emit($event)
# Simple emit to supplier

multi method emit($event, :$type, :%ids!, :$current-version!)
# Emit with optimistic locking support
# - Gets cached data for type/ids
# - TODO: Implement CAS for optimistic locking

method get-events(%ids, %map)
# Filter events by IDs and event type map
# Uses internal &get-events helper

method get-events-after(Int $id, %ids, %map)
# Get events after a specific version ID

method number-of-events
# Returns total event count

multi method store-cached-data($proj where *.HOW.^can("data-to-store"), UInt :$last-id!)
# Store using custom data-to-store method

multi method store-cached-data($proj, Int :$last-id!)
# Store by extracting all public attributes

multi method store-cached-data(Mu:U $proj, %ids, %data, Int :$last-id!)
# Core storage: stores in %!store{ProjectionName}{IDs} => {data, last-id}

method get-cached-data(Mu:U $proj, %ids) is rw
# Retrieves cached state, returns Map with:
# - last-id: atomicint (default -1)
# - data: Hash of projection attributes
```

**Internal Helper**:
```raku
sub get-events(@events, %ids, %map)
# Filters events:
# 1. Keep events where type matches %map keys
# 2. For matching types, check ID fields match %ids values
```

---

## Storage System

### Sourcing::ProjectionStorage

**Purpose**: Special projection that maintains a registry of all projections. Enables automatic projection updates.

**Location**: `lib/Sourcing/ProjectionStorage.rakumod`

**Declaration**:
```raku
unit aggregation Sourcing::ProjectionStorage;
# Uses 'aggregation' to enable event emission
```

**Attributes**:
```raku
has $.id is projection-id = 1;
has %.registries;
has $.supply;
```

**Internal Classes**:
```raku
class ProjectionRegistered {
    has Mu:U $.type;
    has Str $.name;
    has Str @.ids;
    has Hash %.map;
}

class Registry {
    has Str $.name;
    has Mu:U $.type;
    has @.ids;
    has %.map;
}
```

**Public Methods**:
```raku
method start
# Starts the supply:
# 1. Creates sourcing self.WHAT
# 2. Listens to $*SourcingConfig.supply
# 3. Applies events to this storage projection
# 4. Emits ProjectionRegistered events for registered types

multi method apply(ProjectionRegistered (Mu:U :$type, Str :$name, :%map, :@ids))
# Registers a new projection type:
# 1. Adds entries to %!registries for each event type
# 2. Maps event type => Registry

method register(Mu:U $type)
# Registers a projection type
# Emits ProjectionRegistered event

multi method apply(Any $event)
# Applies event to all matching projections:
# 1. Look up registries for event type
# 2. For each registered projection:
#    - Extract ID values from event
#    - Call sourcing to get/create projection
#    - Apply event
```

**Usage**:
```raku
my $storage = Sourcing::ProjectionStorage.new;
await $storage.start;

$storage.register: MyProjection;

# Now any emitted event will automatically update MyProjection instances
```

---

## Traits and Declarations

### Declaring a Projection

```raku
use Sourcing;

projection MyProjection {
    has Int $.id is projection-id;
    has Str $.name;
    
    multi method apply(MyEvent $e) {
        $!name = $e.name;
    }
}
```

**What happens**:
1. `projection` constant triggers `Metamodel::ProjectionHOW`
2. During compose: adds `Sourcing::Projection` role
3. `is projection-id` marks `$.id` as projection identifier
4. Introspection methods become available

### Declaring an Aggregation

```raku
use Sourcing;

aggregation MyAggregation {
    has Int $.id is projection-id;
    has Int $.count = 0;
    
    method apply(MyEvent $e) {
        $!count++;
    }
    
    # Automatically generates my-event() method
}
```

**What happens**:
1. `aggregation` triggers `Metamodel::AggregationHOW` (extends ProjectionHOW)
2. Adds both `Sourcing::Projection` and `Sourcing::Aggregation` roles
3. Generates command methods: `my-event(:$value)` creates `MyEvent` and emits it

### Projection ID Mapping

Default mapping (event field = projection ID name):
```raku
projection A {
    has Int $.id is projection-id;  # Event field 'id' maps to $!id
    
    method apply(MyEvent $e) { }  # Event.$id matches $!id
}
```

Custom mapping via `is projection-id-map`:
```raku
projection B {
    has Int $.id is projection-id;
    
    # Map applies to MyEvent: event field 'x' maps to $!id
    method apply(MyEvent $e) is projection-id-map{ id => "x" } { }
}
```

Shorthand via `is projection-id<>`:
```raku
projection C {
    has Int $.id is projection-id;
    
    # Same as above
    method apply(MyEvent $e) is projection-id< x > { }
}
```

### Command Methods

Mark methods to trigger `^update` after execution:
```raku
aggregation Counter {
    has Int $.id is projection-id;
    has Int $.count = 0;
    
    method apply(Incremented $e) { $!count += $e.amount }
    
    method increment(Int $amount) is command {
        $!count += $amount;
        $.incremented: :$amount;  # Emits event
    }
}
```

After calling `$counter.increment(5)`, the aggregation automatically calls `$counter.^update` to fetch and apply new events.

---

## Usage Patterns

### Basic Projection Creation and Event Application

From `t/03-projection.rakutest`:
```raku
use Sourcing;

projection A {
    has Int $.a is projection-id;
    has Str $.b;
    multi method apply(Int $i) { $!a += $i }
    multi method apply(Str $s) { $!b ~= $s }
}

# Create with ID
my $a = A.new: :1a;
is $a.a, 1;

# Create with initial events
$a = A.new: :initial-events[1, 2, 3];
is $a.a, 6;

# Apply events
$a.apply: 3;
is $a.a, 9;
```

### Aggregations with Event Emission

From `t/05-aggregation.rakutest`:
```raku
use Sourcing;
use Sourcing::Plugin::Memory;

Sourcing::Plugin::Memory.use;

class MyEvent { has $.a; has $.b; has $.x }

aggregation A {
    has Int $.a is projection-id;
    has Str $.b;
    multi method apply(MyEvent $i) { $!a += $i }
}

my $a = A.new: :42a;

# Auto-generated method emits event
is-deeply $a.my-event(:b<bla>), MyEvent.new: :42a, :b<bla>;
# Event is emitted to supply
is-deeply $emitted-events, MyEvent.new: :42a, :b<bla>;
```

### Sourcing Function for Instance Management

From `t/06-emit-and-get.rakutest`:
```raku
use Sourcing;
use Sourcing::Plugin::Memory;

Sourcing::Plugin::Memory.use;

my class MyEvent { has $.id; has $.value }

aggregation A {
    has Int $.id is projection-id;
    has Int $.value = 0;
    multi method apply(MyEvent $_) { $!value += .value }
}

# Create/get projection for specific ID
my $a = sourcing A, :42id;
is $a.id, 42;
is $a.value, 0;

# Emit event
$a.my-event: :3value;
# Value is still 0 until update

# Update fetches new events
$a.^update;
is $a.value, 3;

# Get same instance again - same state
my $b = sourcing A, :42id;
is-deeply $b, $a;
```

### Account Aggregate Example

From `t/08-accounts.rakutest`:
```raku
class AccountOpened { has UInt $.account-id; has Rat $.initial-amount }
class Deposited { has UInt $.account-id; has Rat $.amount }
class Withdrew { has UInt $.account-id; has Rat $.amount }
class AccountClosed { has UInt $.account-id }

aggregation Account {
    has UInt $.account-id is required is projection-id;
    has Rat $.amount where * >= 0;
    has Bool $.active = False;

    multi method apply(AccountOpened $_) {
        $!account-id = .account-id;
        $!amount = .initial-amount;
        $!active = True;
    }

    multi method apply(Deposited $_) { $!amount += .amount }
    multi method apply(Withdrew $_) { $!amount -= .amount }
    multi method apply(AccountClosed $_) { $!active = False }

    method open-account(::?CLASS:U: Rat() $initial-amount) {
        my $account-id = $next-id++;
        my $new = sourcing self, :$account-id;
        $new.account-opened: :$initial-amount;
    }

    method deposit(Rat() $amount) {
        die "Account not active" unless $!active;
        $.deposited: :$amount;
    }
}

# Usage
my $e1 = Account.open-account: 100;
my $a1 = sourcing Account, account-id => $e1.account-id;
$a1.deposit: 50;
```

### Projection Storage for Automatic Updates

From `t/07-projection-storage.rakutest`:
```raku
use Sourcing::ProjectionStorage;
use Sourcing::Plugin::Memory;

Sourcing::Plugin::Memory.use;

aggregation A {
    has Int $.id is projection-id;
    has Int $.value = 0;
    multi method apply(MyEvent $_) { $!value += .value }
}

my $storage = Sourcing::ProjectionStorage.new;
start {
    await Promise.in: .1;
    $storage.register: A;
    
    my $a = sourcing A, :1id;
    $a.my-event: :1value;  # Emits event
}

await $storage.start;
# Storage listens to events and updates all projections
```

### Command Methods with Auto-Update

From `t/09-update.rakutest`:
```raku
aggregation A {
    has Int $.id is projection-id;
    has Int $.value = 0;
    method apply(MyEvent $_) { $!value += .value }
    
    method value-is($is) is command {
        $.my-event: :value($is);
    }
}

my $a = A.new: :1id;
$a.value-is: 6;
$a.^update;  # Auto-called after value-is due to is command trait
is $value, 6;
```

---

## Exception Classes

### Sourcing::X::OptmisticLocked

**Purpose**: Exception thrown when optimistic locking fails.

**Location**: `lib/Sourcing/X/OptmisticLocked.rakumod`

```raku
unit class Sourcing::X::OptmisticLocked is Exception;

method message { "<sourcing optmitic locked>" }
```

**Note**: Currently not actively used (marked TODO in code for CAS implementation).

---

## Index of Files

| File | Purpose |
|------|---------|
| `lib/Sourcing.rakumod` | Main module, exports traits, sourcing function |
| `lib/Sourcing/Projection.rakumod` | Role for all projections |
| `lib/Sourcing/Aggregation.rakumod` | Role marker for aggregations |
| `lib/Sourcing/ProjectionId.rakumod` | Role for projection ID attributes |
| `lib/Sourcing/ProjectionIdMap.rakumod` | Role for method ID mapping |
| `lib/Sourcing/ProjectionStorage.rakumod` | Registry projection |
| `lib/Sourcing/Plugin.rakumod` | Abstract plugin interface |
| `lib/Sourcing/Plugin/Memory.rakumod` | In-memory plugin implementation |
| `lib/Sourcing/X/OptmisticLocked.rakumod` | Optimistic locking exception |
| `lib/Metamodel/ProjectionHOW.rakumod` | Metaclass for projections |
| `lib/Metamodel/AggregationHOW.rakumod` | Metaclass for aggregations |
| `lib/Metamodel/ProjectionIdContainer.rakumod` | ID introspection role |
| `lib/Metamodel/EventHandlerContainer.rakumod` | Event handler introspection role |

---

## Testing Files

| Test File | Coverage |
|-----------|----------|
| `t/01-basic.rakutest` | Placeholder test |
| `t/02-projection-role.rakutest` | Direct Sourcing::Projection role usage |
| `t/03-projection.rakutest` | Projection declarations, ID mapping, multi apply |
| `t/05-aggregation.rakutest` | Aggregation with event emission, ID mapping |
| `t/06-emit-and-get.rakutest` | Sourcing function, update, caching |
| `t/07-projection-storage.rakutest` | ProjectionStorage registry, auto-update |
| `t/08-accounts.rakutest` | Full account aggregate example |
| `t/09-update.rakutest` | Command methods with auto-update |