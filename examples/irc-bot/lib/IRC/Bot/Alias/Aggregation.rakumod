use v6.e.PREVIEW;

use Sourcing;
use IRC::Bot::Alias::Events;

=begin pod

=head1 NAME

IRC::Bot::Alias::Aggregation - Alias aggregation

=head1 DESCRIPTION

The Alias aggregation manages command aliases for users.
Handles commands for setting and removing aliases.
Emits appropriate events.

=end pod

aggregation IRC::Bot::Alias::Aggregation {

    has Str $.alias is projection-id;

    # Alias state
    has Str $.command;
    has Str $.set-by;
    has DateTime $.set-at;
    has Int $.usage-count = 0;

    =begin pod

    =head2 Method apply

    Event handlers to rebuild aggregate state from events.

    =end pod

    multi method apply(AliasSet $e) {
        $!command = $e.command;
        $!set-by = $e.set-by;
        $!set-at = $e.set-at;
    }

    multi method apply(AliasRemoved $e) {
        # Mark as removed - in a real system, might use soft delete
        $!command = Nil;
    }

    =begin pod

    =head2 Method set-alias

    Command to set an alias for a command.
    Emits an AliasSet event.

    =end pod

    method set-alias(Str :$command, Str :$set-by) is command {
        self.alias-set(
            :$command,
            :$set-by,
            :set-at(DateTime.now)
        );
    }

    =begin pod

    =head2 Method remove-alias

    Command to remove an alias.
    Emits an AliasRemoved event.

    =end pod

    method remove-alias(Str :$removed-by) is command {
        self.alias-removed(
            :$removed-by,
            :removed-at(DateTime.now)
        );
    }

    =begin pod

    =head2 Method increment-usage

    Internal method to increment usage count (not exposed as command).

    =end pod

    method increment-usage() {
        $!usage-count++;
    }
}
