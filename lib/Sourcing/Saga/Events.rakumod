use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Saga::Events - Internal event classes for saga coordination

=head1 DESCRIPTION

These event classes are used internally by the saga system for timeout
scheduling, timeout firing, saga creation, and aggregation binding.

=end pod

unit class Sourcing::Saga::Events;

our class TimeOutScheduled is export {
    has $.saga-id;
    has Str $.handler-name;
    has DateTime $.scheduled-at;
}

our class TimedOut is export {
    has $.saga-id;
    has Str $.handler-name;
}

our class SagaCreated is export {
    has $.saga-id;
    has $.saga-type;
    has Hash %.aggregation-ids;
}

our class SagaAggregationBound is export {
    has $.saga-id;
    has Str $.attribute-name;
    has Str $.aggregation-type;
    has Hash %.ids;
}