use v6.e.PREVIEW;

use Sourcing;
use IRC::Client;
use IRC::Bot::Projections::KarmaProjection;
use IRC::Bot::Alias::Projection;

=begin pod

=head1 NAME

IRC::Plugin::Karma - IRC plugin for karma and alias queries

=head1 DESCRIPTION

Handles IRC messages that start with '!' and queries projections directly.
This follows CQRS principles - queries go to projections, not sagas.

Supported commands:
- !karma [nick] - query karma score for a nick
- !aliases [nick] - show aliases for a nick
- !help - show help text

=end pod

class IRC::Plugin::Karma does IRC::Client::Plugin {
    has $.nickname is rw;
    has $.channels is rw;

    method irc-privmsg-channel($event) {
        my $text = $event.text;
        my $channel = $event.channel;
        my $nick = $event.nick;

        # Skip messages from the bot itself
        return if $nick eq $.nickname;

        # Handle !karma command - query KarmaProjection directly
        if $text ~~ /^\!karma$/ {
            my $karma-proj = sourcing IRC::Bot::Projections::KarmaProjection, :target($nick);
            my $score = $karma-proj.score // 0;
            $event.irc.send(:where($channel), :text("$nick has $score karma"));
            return;
        }

        if $text ~~ /^\!karma <[\s]>+ (<[\S]>+)$/ {
            my $target = ~$0;
            my $karma-proj = sourcing IRC::Bot::Projections::KarmaProjection, :target($target);
            my $score = $karma-proj.score // 0;
            $event.irc.send(:where($channel), :text("$target has $score karma"));
            return;
        }

        # Handle !aliases command - query AliasProjection directly
        if $text ~~ /^\!aliases$/ {
            my $target = $nick;
            # Find all aliases where the target is either the alias or the command contains the target
            my @all-aliases = sourcing IRC::Bot::Alias::Projection.^load-all;
            my @matching = @all-aliases.grep: { .is-active && (.alias eq $target || .command.contains($target)) };

            if @matching.elems == 0 {
                $event.irc.send(:where($channel), :text("$target has no aliases"));
            } else {
                my $list = @matching.map({ "$_.alias => $_.command" }).join(', ');
                $event.irc.send(:where($channel), :text("$target aliases: $list"));
            }
            return;
        }

        if $text ~~ /^\!aliases <[\s]>+ (<[\S]>+)$/ {
            my $target = ~$0;
            # Find all aliases where the target is either the alias or the command contains the target
            my @all-aliases = sourcing IRC::Bot::Alias::Projection.^load-all;
            my @matching = @all-aliases.grep: { .is-active && (.alias eq $target || .command.contains($target)) };

            if @matching.elems == 0 {
                $event.irc.send(:where($channel), :text("$target has no aliases"));
            } else {
                my $list = @matching.map({ "$_.alias => $_.command" }).join(', ');
                $event.irc.send(:where($channel), :text("$target aliases: $list"));
            }
            return;
        }

        # Handle !help command
        if $text.trim eq '!help' {
            $event.irc.send(:where($channel), :text("Commands: !karma [nick], !aliases [nick], !help, ++nick, --nick, nick=>newnick"));
            return;
        }
    }
}
