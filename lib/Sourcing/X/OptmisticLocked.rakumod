=begin pod

=head1 NAME

Sourcing::X::OptmisticLocked - Exception for optimistic locking failures

=head1 DESCRIPTION

This exception is thrown when an optimistic locking conflict occurs during event
emission. It indicates that another process has modified the aggregate state
since the expected version was read.

=end pod

unit class Sourcing::X::OptmisticLocked is Exception;

=begin pod

=head1 METHODS

=head2 method message

Returns the exception message describing the optimistic lock failure.

=head3 Returns

A string describing the error condition.

=end pod

method message { "<sourcing optmitic locked>" }
