=begin pod

=head1 NAME

Sourcing::X::OptimisticLocked - Exception for optimistic locking failures

=head1 DESCRIPTION

This exception is thrown when an optimistic locking conflict occurs during event
emission. It indicates that another process has modified the aggregate state
since the expected version was read.

=end pod

unit class Sourcing::X::OptimisticLocked is Exception;

has Mu:U $.type;
has Hash $.ids;
has Int $.expected-version;
has Int $.actual-version;

method message {
	"<sourcing optimistic locked: type=$!type.^name, ids={$.ids.raku}, "
	~ "expected-version=$!expected-version, actual-version=$!actual-version>"
}

submethod BUILD(:$type, :%ids, :$expected-version, :$actual-version) {
	$!type = $type;
	$!ids = %ids;
	$!expected-version = $expected-version;
	$!actual-version = $actual-version;
}
