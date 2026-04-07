#!/usr/bin/env raku
use v6.e.PREVIEW;
use lib '/Users/fernando/Projects/Sourcing/lib';

use Sourcing;
use Sourcing::Plugin::Memory;
use IRC::Client;

use IRC::Bot::Channel::Aggregation;
use IRC::Bot::Channel::Events;
use IRC::Bot::Projections::KarmaProjection;
use IRC::Bot::Alias::Projection;
use IRC::Bot::Karma::Events;
use IRC::Bot::Saga::KarmaHandler;
use IRC::Bot::Saga::AliasHandler;
use IRC::Bot::Saga::Supply;

sub load-config(Str $file) {
    my %config;
    for $file.IO.lines -> $line {
        next if $line.trim.starts-with('#') || !$line.trim.contains('=');
        my ($key, $value) = $line.split('=', 2).map({.trim});
        next unless $key && $value;
        %config{$key} = $value;
    }
    %config
}

class BotConfig {
    has $.nickname;
    has $.server;
    has $.port;
    has $.username;
    has $.realname;
    has @.channels;
    has $.verbose = False;
    has $.ssl = False;
    
    method new() {
        my %c = load-config("examples/irc-bot/config.toml");
        my $port-str = %c<port> // "6667";
        my $port = $port-str.Int;
        my $ssl-enabled = (%c<ssl> // "false") eq "true" || $port == 6697;
        self.bless(
            :nickname(%c<nickname> // "sourcing-bot"),
            :server(%c<server> // "irc.libera.chat"),
            :port($port),
            :username(%c<username> // %c<nickname> // "sourcing-bot"),
            :realname(%c<realname> // "Sourcing IRC Bot"),
            :channels((%c<channels> // "#sourcing").split(',')),
            :verbose((%c<verbose> // "false") eq "true"),
            :ssl($ssl-enabled),
        );
    }
}

class Plugin does IRC::Client::Plugin {
    has BotConfig $.config;
    has $!store;
    
    submethod BUILD(:$!config, :$!store) { }
    
    method irc-connected($event) {
        say "CONNECTED! Joining channels...";
        for $!config.channels -> $ch {
            $event.irc.join($ch);
        }
    }
    
    method irc-join($event) {
        say "JOINED: {$event.nick} in {$event.channel}";
    }
    
    method irc-privmsg-channel($event) {
        my $text = $event.text;
        my $channel = $event.channel;
        my $nick = $event.nick;
        
        # Skip messages from the bot itself
        return if $nick eq $.config.nickname;
        
        # Only handle '!' prefix commands as QUERIES (reads) - these query projections directly
        # Queries do NOT emit events - that's CQRS!
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
        
        if $text ~~ /^\!aliases$/ {
            my $target = $nick;
            my @all-aliases = IRC::Bot::Alias::Projection.^load-all;
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
            my @all-aliases = IRC::Bot::Alias::Projection.^load-all;
            my @matching = @all-aliases.grep: { .is-active && (.alias eq $target || .command.contains($target)) };
            
            if @matching.elems == 0 {
                $event.irc.send(:where($channel), :text("$target has no aliases"));
            } else {
                my $list = @matching.map({ "$_.alias => $_.command" }).join(', ');
                $event.irc.send(:where($channel), :text("$target aliases: $list"));
            }
            return;
        }
        
        if $text.trim eq '!help' {
            $event.irc.send(:where($channel), :text("Commands: !karma [nick], !aliases [nick], ++nick, --nick, nick=>newnick, !help"));
            return;
        }
        
        # For ALL other messages - emit a MessageReceived event through the Channel aggregation
        # This is the COMMAND path (write) - the sagas will handle ++, --, => patterns
        my $channel-agg = sourcing IRC::Bot::Channel::Aggregation, :channel($channel);
        $channel-agg.receive-message: :$nick, :message($text);
        
        # NOTE: We do NOT respond to ++/--/=> here - that's the saga's job
        # The saga consumes the MessageReceived event and calls the appropriate aggregation commands
        # Any responses to commands come from separate query plugins, not here
        
        Nil
    }
}

sub MAIN() {
    my $config = BotConfig.new;
    
    say "Connecting to {$config.server}:{$config.port}";
    say "Channels: {$config.channels.join(', ')}";
    
    # Initialize the memory store
    my $store = Sourcing::Plugin::Memory.new;
    $store.use;
    
    # Get reference to SourcingConfig process variable after store is used
    my $sourcing-config = sourcing-config;
    
    # Set up a callback for saga responses to be sent back to IRC
    my %channel-callbacks;
    for $config.channels -> $ch {
        set-channel-callback($ch, -> $response {
            # Responses from sagas go to the channel (handled out-of-band)
            say "SAGA RESPONSE: $response";
        });
    }
    
    # Start the saga supply to process events through sagas
    start-saga-supply($sourcing-config, :verbose($config.verbose));
    
    my $plugin = Plugin.new(:$config, :$store);
    
    IRC::Client.new(
        :host($config.server),
        :port($config.port),
        :nick($config.nickname),
        :username($config.username),
        :realname($config.realname),
        :channels($config.channels),
        :debug($config.verbose),
        :ssl($config.ssl),
        :plugins($plugin)
    ).run;
}
