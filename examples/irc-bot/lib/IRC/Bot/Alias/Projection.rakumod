use v6.e.PREVIEW;

use Sourcing;
use IRC::Bot::Alias::Events;

=begin pod

=head1 NAME

IRC::Bot::Alias::Projection - Alias projection

=head1 DESCRIPTION

A read model that tracks command aliases set by users.
Allows users to define shortcuts for common commands.

=end pod

projection IRC::Bot::Alias::Projection {

    has Str $.alias is projection-id;
    has Str $.command;
    has Str $.set-by;
    has DateTime $.set-at;
    has Int $.usage-count = 0;

    =begin pod

    =head2 Method apply

    Apply events to update the alias projection.

    =end pod

    multi method apply(AliasSet $e) {
        $!command = $e.command;
        $!set-by = $e.set-by;
        $!set-at = $e.set-at;
        $!usage-count = 0; # Reset usage count when alias is set/changed
    }

    multi method apply(AliasRemoved $e) {
        # Mark as removed - in a real system, might use soft delete
        $!command = Nil;
    }

    =begin pod

    =head2 Method is-active

    Returns True if the alias is active (has a command).

    =end pod

    method is-active() {
        defined $!command;
    }

    =begin pod

    =head2 Method all-aliases

    Returns all active aliases.

    =end pod

    method all-aliases() {
        my @all = self.^load-all;
        @all.grep: *.is-active;
    }

    =begin pod

    =head2 Method increment-usage

    Increments the usage count for this alias.

    =end pod

    method increment-usage() {
        $!usage-count++;
    }
}
