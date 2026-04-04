# Agent Guidelines for Sourcing

## Project Overview

This is a Raku (Perl 6) event sourcing library. The codebase uses metaclasses for projections and aggregations, with roles for composition.

---

## Build, Test, and Lint Commands

### Running All Tests
```bash
mi6 test
```

### Running a Single Test
```bash
mi6 test t/01-basic.rakutest
```

### Installing Dependencies
```bash
zef install --/test --test-depends --deps-only .
```

### Installing App::Mi6 (if needed)
```bash
zef install App::Mi6
```

---

## Code Style Guidelines

### General Conventions

- **File extension**: `.rakumod` for modules, `.rakutest` for tests
- **Unit declarations**: Use `unit class`, `unit role`, `unit module` at the top level
- **Indentation**: 4 spaces
- **Line length**: No strict limit, but prefer under 120 chars

### Imports

```raku
use Sourcing::Projection;      # External module
use Sourcing::X::OptimisticLocked;  # Custom exception
use v6.e.PREVIEW;               # Language version (when needed)
```

- Order: `v6.e.PREVIEW` first (if needed), then core modules, then external, then internal
- Use `use` for all imports (no `need` except for precompilation)

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes | CamelCase | `ProjectionStorage` |
| Roles | CamelCase | `Sourcing::Projection` |
| Methods | camelCase | `apply`, `get-events-after` |
| Attributes (public) | `$.name` | `$.id`, `$.supply` |
| Attributes (private) | `$!name` | `$!type`, `$!supply` |
| Constants | UPPER_SNAKE | `projection`, `aggregation` |
| Packages | CamelCase | `EXPORTHOW`, `DECLARE` |

### Types

- Use explicit types on attributes and parameters
- Use `Mu` for generic types, `Mu:U` for undefined-only type objects
- Use `Any` as fallback for dynamic types

```raku
has Mu:U $.type;           # Type object only
has Str  $.name;           # String
has Str  @.ids;            # Array of strings
has Hash %.map{Mu} = {};   # Hash with Mu keys
```

### Roles and Metaclasses

- Roles use `unit role` declaration
- Metaclasses inherit from `Metamodel::ClassHOW`
- Use `also does` for role composition

```raku
unit role Sourcing::Projection;

unit class Metamodel::ProjectionHOW is Metamodel::ClassHOW;
also does Metamodel::ProjectionIdContainer;
also does Metamodel::EventHandlerContainer;
```

### Exports and Traits

- Use `is export` for exported symbols
- Use `trait_mod:<is>` for custom traits

```raku
sub sourcing-config is rw is export { ... }

multi trait_mod:<is>(Method $m, Bool :$command where *.so) is export { ... }
```

### Error Handling

- Custom exceptions go in `Sourcing::X::*` namespace
- Inherit from `Exception`

```raku
unit class Sourcing::X::OptimisticLocked is Exception;
method message { "<sourcing optimistic locked>" }
```

- Use `die` for fatal errors with descriptive messages

```raku
die "Trying to set a generic projection id to a method on a type with multiple or no projection ids (@ids.join(", "))"
```

### Testing

- Test files go in `t/*.rakutest`
- Use `use Test;` and `use Sourcing;`
- End with `done-testing;`

```raku
use Test;
use Sourcing;

pass "test name";

done-testing;
```

### Package/Module Structure

```
lib/
├── Sourcing.rakumod              # Main module
├── Sourcing/
│   ├── Projection.rakumod        # Role
│   ├── Aggregation.rakumod      # Role
│   ├── ProjectionStorage.rakumod
│   └── X/
│       └── OptimisticLocked.rakumod
└── Metamodel/
    ├── ProjectionHOW.rakumod
    └── ...
t/
├── 01-basic.rakutest
└── ...
```

---

## Important Patterns

### Projection Definition
```raku
class MyProjection is Sourcing::Projection {
    has $.id is projection-id;
    has $.name;

    method apply(MyEvent $e) { ... }
}
```

### Aggregation Definition
```raku
class MyAggregation is Sourcing::Aggregation {
    has $.id is projection-id;
    has $.total = 0;

    method apply(MyEvent $e) { ... }
}
```

### Supply/Event Handling
```raku
method start {
    $!supply = supply {
        my $s = sourcing self.WHAT;
        whenever $*SourcingConfig.supply -> $event {
            $s.apply: $event
        }
    }
}
```
