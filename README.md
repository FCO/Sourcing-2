[![Actions Status](https://github.com/FCO/Sourcing-2/actions/workflows/test.yml/badge.svg)](https://github.com/FCO/Sourcing-2/actions)

NAME
====

Sourcing - Event sourcing library for Raku

DESCRIPTION
===========

Sourcing is a Raku event sourcing library that provides projections and aggregations for building event-driven applications. It uses metaclasses for projections and aggregations, with roles for composition.

SYNOPSIS
========

    use Sourcing;

    class MyProjection is Sourcing::Projection {
        has $.id is projection-id;
        has $.name;

        method apply(MyEvent $e) { ... }
    }

VARIABLES
=========

sub sourcing-config
-------------------

Global configuration variable for the current sourcing context. Returns a Process variable that stores the active plugin configuration.

SUBROUTINES
===========

sub sourcing
------------

Creates a fresh projection/aggregation instance, applying all events from the event store for the given identity.

### Parameters

#### `$proj` — The projection type to instantiate (must be a [Sourcing::Projection](Sourcing::Projection))

#### `*%ids` — Named arguments for the projection's identity attributes

### Returns

A new instance of the projection type with all relevant events applied. Each call to `sourcing` creates a fresh instance; it does not return cached instances.

### Example

    my $projection = sourcing MyProjection, :id($some-id);

TRAITS
======

trait_mod:<is>
--------------

Custom traits for marking methods as commands and attributes as projection identifiers.

### trait_mod:<is>(Method $m, Bool :$command)

Marks a method as a command. When called, the method is wrapped in a retry loop that:

1. Calls `^update` to reset and replay the aggregate from the event store 2. Executes the command body (validation and event emission) 3. If `Sourcing::X::OptimisticLocked` is thrown during event emission, the loop retries from step 1 (up to 5 attempts total) 4. Non-locking exceptions (e.g., validation errors) are re-thrown immediately without retry 5. After exhausting all 5 attempts, the last `X::OptimisticLocked` exception is re-thrown

### trait_mod:<is>(Method $m, :$projection-id-map)

Associates a method with a projection ID map, allowing custom event-to-attribute mappings.

### trait_mod:<is>(Method $r, Str :$projection-id)

Marks a method as providing a projection identifier. The method's return value becomes part of the aggregate's identity for event correlation.

### trait_mod:<is>(Attribute $r, Bool :$projection-id)

Marks an attribute as a projection identifier. This attribute's value is used to correlate events with specific projection instances.

