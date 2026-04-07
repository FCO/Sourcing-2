use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::IRCBot::Events;

=begin pod

=head1 NAME

Sourcing::Example::IRCBot::Aggregates::UserAggregate - IRC user aggregate

=head1 DESCRIPTION

The UserAggregate manages IRC user state. It handles:
- User login/logout tracking
- Nickname changes
- Karma scores
- Command aliases

This aggregate represents a single IRC user and tracks their
identity and preferences.

=end pod

aggregation Sourcing::Example::IRCBot::Aggregates::UserAggregate {

    # Identity
    has Str $.nickname is projection-id;

    # User state
    has Str $.ident;
    has Str $.host;
    has Bool $.is-online = False;
    has Int $.karma = 0;

    # Session tracking
    has DateTime $.last-seen;
    has Int $.channels-joined = 0;
    has Int $.messages-sent = 0;

    # Aliases: alias-name => command
    has Str %.aliases = {};

    =begin pod

    =head2 Method apply

    Event handlers to rebuild aggregate state from events.

    =end pod

    multi method apply(UserLogin $e) {
        $!nickname = $e.nickname;
        $!ident = $e.ident;
        $!host = $e.host;
        $!is-online = True;
        $!last-seen = $e.login-at;
    }

    multi method apply(UserLogout $e) {
        $!is-online = False;
        $!last-seen = $e.logout-at;
    }

    multi method apply(NickChanged $e) is projection-id< old-nickname > {
        $!nickname = $e.new-nickname;
        $!last-seen = $e.changed-at;
    }

    multi method apply(KarmaIncreased $e) {
        $!karma += $e.amount;
    }

    multi method apply(KarmaDecreased $e) {
        $!karma -= $e.amount;
    }

    multi method apply(KarmaReset $e) {
        $!karma = 0;
    }

    multi method apply(AliasSet $e) {
        %.aliases{$e.alias} = $e.command;
    }

    multi method apply(AliasRemoved $e) {
        %.aliases{$e.alias}:delete;
    }

    =begin pod

    =head2 Method login

    Command to record user login.

    =end pod

    method login(Str :$ident, Str :$host) is command {
        die "User $!nickname is already online"
        if $!is-online;

        my $event = UserLogin.new:
        :nickname($!nickname),
        :$ident,
        :$host,
        :login-at(DateTime.now);

        $event.emit: :type(self.WHAT);
    }

    =begin pod

    =head2 Method logout

    Command to record user logout.

    =end pod

    method logout(Str :$reason = '') is command {
        die "User $!nickname is not online"
        unless $!is-online;

        my $event = UserLogout.new:
        :nickname($!nickname),
        :$reason,
        :logout-at(DateTime.now);

        $event.emit: :type(self.WHAT);
    }

    =begin pod

    =head2 Method change-nickname

    Command to change user's nickname.

    =end pod

    method change-nickname(Str :$new-nickname) is command {
        die "User $!nickname is not online"
        unless $!is-online;

        my $event = NickChanged.new:
        :old-nickname($!nickname),
        :new-nickname($new-nickname),
        :changed-at(DateTime.now);

        $event.emit: :type(self.WHAT);
    }

    =begin pod

    =head2 Method increase-karma

    Command to increase user's karma.

    =end pod

    method increase-karma(Str :$changed-by, Int :$amount = 1) is command {
        my $event = KarmaIncreased.new:
        :target($!nickname),
        :$changed-by,
        :$amount,
        :changed-at(DateTime.now);

        $event.emit: :type(self.WHAT);
    }

    =begin pod

    =head2 Method decrease-karma

    Command to decrease user's karma.

    =end pod

    method decrease-karma(Str :$changed-by, Int :$amount = 1) is command {
        my $event = KarmaDecreased.new:
        :target($!nickname),
        :$changed-by,
        :$amount,
        :changed-at(DateTime.now);

        $event.emit: :type(self.WHAT);
    }

    =begin pod

    =head2 Method reset-karma

    Command to reset user's karma to zero.

    =end pod

    method reset-karma(Str :$reset-by) is command {
        my $event = KarmaReset.new:
        :target($!nickname),
        :$reset-by,
        :reset-at(DateTime.now);

        $event.emit: :type(self.WHAT);
    }

    =begin pod

    =head2 Method set-alias

    Command to set a command alias.

    =end pod

    method set-alias(Str :$alias, Str :$command, Str :$set-by) is command {
        die "Cannot set empty alias" unless $alias;
        die "Cannot set empty command" unless $command;

        my $event = AliasSet.new:
        :$alias,
        :$command,
        :$set-by,
        :set-at(DateTime.now);

        $event.emit: :type(self.WHAT);
    }

    =begin pod

    =head2 Method remove-alias

    Command to remove a command alias.

    =end pod

    method remove-alias(Str :$alias, Str :$removed-by) is command {
        die "Alias $alias does not exist"
        unless %.aliases{$alias}:exists;

        my $event = AliasRemoved.new:
        :$alias,
        :$removed-by,
        :removed-at(DateTime.now);

        $event.emit: :type(self.WHAT);
    }

    =begin pod

    =head2 Method record-message

    Command to record a message sent by the user.

    =end pod

    method record-message() is command {
        $!messages-sent++;
        $!last-seen = DateTime.now;
    }

    =begin pod

    =head2 Method joined-channel

    Command to record user joining a channel.

    =end pod

    method joined-channel() is command {
        $!channels-joined++;
    }

    =begin pod

    =head2 Method info

    Returns user information.

    =end pod

    method info() {
        {
            nickname => $!nickname,
            ident => $!ident,
            host => $!host,
            is-online => $!is-online,
            karma => $!karma,
            last-seen => $!last-seen,
            messages-sent => $!messages-sent,
            channels-joined => $!channels-joined,
            aliases => %.aliases
        }
    }
}
