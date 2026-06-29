# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
zef install --/test --test-depends --deps-only .

# Run all tests
prove6 -Ilib t
# or
mi6 test

# Run a single test
mi6 test t/01-basic.rakutest
```

## Architecture

This is a **Raku** event sourcing library implementing CQRS. The three core concepts:

| Type | HOW metaclass | Role | Purpose |
|---|---|---|---|
| `projection` | `ProjectionHOW` | `Sourcing::Projection` | Read models — consume events, build query-optimized state |
| `aggregation` | `AggregationHOW` | `Sourcing::Aggregation` | Write side — validate commands, emit events |
| `saga` | `SagaHOW` | `Sourcing::Saga` | Long-running orchestration across aggregations |

### How metaclasses wire things together

`lib/Sourcing.rakumod` is the entry point. It exports the `projection`, `aggregation`, and `saga` constants (which name their corresponding HOW classes) plus `sourcing()`, traits, and `EXPORTHOW`/`DECLARE`.

When you write `projection Foo { ... }`, Raku uses `Metamodel::ProjectionHOW` as the metaclass. During `compose`:
1. **ProjectionHOW** (`lib/Metamodel/ProjectionHOW.rakumod`) composes `Sourcing::Projection` role and two helper roles: `ProjectionIdContainer` (finds `is projection-id` attributes) and `EventHandlerContainer` (inspects `apply` multi-method candidates to discover handled event types and their ID mappings).
2. **AggregationHOW** (`lib/Metamodel/AggregationHOW.rakumod`) extends ProjectionHOW, adds `Sourcing::Aggregation` role, and **auto-generates emit methods** — for every event type handled by an `apply` method, a kebab-case method (e.g., `my-event`) is added that builds the event with the projection ID pre-filled and calls `$*SourcingConfig.emit`.
3. **SagaHOW** (`lib/Metamodel/SagaHOW.rakumod`) extends AggregationHOW, adds `Sourcing::Saga` role, generates internal event handlers for `TimeOutScheduled`/`TimedOut`/`SagaCreated`/`SagaAggregationBound`, validates `is on-state()` guards against declared states at compose time, and wraps all methods with exception handling (any uncaught exception triggers `rollback()` and transitions to `'failed'`).

### Plugin system

`Sourcing::Plugin` (`lib/Sourcing/Plugin.rakumod`) is the abstract role. Implementations:
- `Sourcing::Plugin::Memory` — in-memory, used in tests
- `Sourcing::Plugin::EventStore::SQLite` — SQLite-backed

Install with `Sourcing::Plugin::Memory.use` — this sets the process-level dynamic variable `$*SourcingConfig`. The `sourcing()` function, emit methods, and `^update`/`^rebuild` metaclass methods all read from `$*SourcingConfig`.

### Key dynamic variables

- `$*SourcingConfig` — the active plugin instance (set via `Plugin.use`)
- `$*SourcingReplay` — when truthy, all `is command` methods return `Nil` immediately without running. Set during `^rebuild` and when replaying already-consumed saga events in `^update`.

### Command retry loop

Every `is command` method is wrapped by `AggregationHOW` with a retry loop:
1. Call `^update` (restore from cache, apply new events)
2. Execute the method body (validate, emit events)
3. If `X::OptimisticLocked` is thrown (concurrent write detected), retry from step 1
4. After 5 failed attempts, re-throw the last `X::OptimisticLocked`

### `sourcing()` function

`sourcing(MyType, :id(42))` creates a fresh instance by fetching all events for that identity from the store and applying them. It does **not** return cached instances — each call replays. Use `^update` for incremental updates on an existing instance.

### `Sourcing::ProjectionStorage`

`lib/Sourcing/ProjectionStorage.rakumod` — a registry that automatically routes events to registered projections. Declared as an `aggregation` so it can emit `ProjectionRegistered` events while also consuming the event stream to forward to registered projections.

## Code conventions

- File extensions: `.rakumod` for modules, `.rakutest` for tests
- Top-level declarations: `unit class`, `unit role`, `unit module`
- Methods: kebab-case (`get-events-after`); classes/roles: CamelCase
- Public attributes: `$.name`; private: `$!name`
- Custom exceptions live in `Sourcing::X::*` and inherit from `Exception`
- Test files in `t/` use `use Test;` and end with `done-testing;`
- Imports: `v6.e.PREVIEW` first (if needed), then core, external, internal
- Language: all generated content — code, comments, docstrings/POD, documentation, commit messages — must be written in English. Chat replies may use another language.
