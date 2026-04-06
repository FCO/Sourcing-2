#!/usr/bin/env raku
use v6.e.PREVIEW;
use lib '/Users/fernando/Projects/Sourcing/lib';

use Sourcing;
use Sourcing::Plugin::Memory;
use IRC::Client;
use Sourcing::Example::IRCBot::Events;

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

projection KarmaProjection {
    has Str $.target is projection-id;
    has Int $.karma = 0;
    
    multi method apply(KarmaIncreased $e) { $!karma += $e.amount; }
    multi method apply(KarmaDecreased $e) { $!karma -= $e.amount; }
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
    
    method irc-event($event) {
        #say "EVENT: {$event.command}";
    }
    
    method irc-privmsg-channel($event) {
        my $text = $event.text;
        
        if $text ~~ /^^(\S+)\+\+$ || ^^\+\+(\S+)$/ {
            my $target = ~($0 || $1);
            my $e = KarmaIncreased.new(:$target, :changed-by($event.nick), :amount(1), :changed-at(DateTime.now));
            $*SourcingConfig.emit: $e, :type(KarmaProjection), :ids{:$target};
            my $karma = sourcing KarmaProjection, :$target;
            $event.reply: "$target: {$karma.karma // 0} karma";
            return;
        }
        
        if $text ~~ /^^(\S+)\-\-$ || ^^\-\-(\S+)$/ {
            my $target = ~($0 || $1);
            my $e = KarmaDecreased.new(:$target, :changed-by($event.nick), :amount(1), :changed-at(DateTime.now));
            $*SourcingConfig.emit: $e, :type(KarmaProjection), :ids{:$target};
            my $karma = sourcing KarmaProjection, :$target;
            $event.reply: "$target: {$karma.karma // 0} karma";
            return;
        }
        
        if $text ~~ /^\!karma[\s+(\S+)]?/ {
            my $target = ~($0 || $event.nick);
            my $karma = sourcing KarmaProjection, :$target;
            $event.reply: "$target has {$karma.karma // 0} karma";
            return;
        }
        
        if $text eq '!help' {
            $event.reply: "Commands: ++user, --user, !karma [user], !help";
            return;
        }
        
        if $text.starts-with('!') {
            $event.reply: "Unknown. Try !help";
        }

        Nil
    }
}

sub MAIN() {
    my $config = BotConfig.new;
    
    say "Connecting to {$config.server}:{$config.port}";
    say "Channels: {$config.channels.join(', ')}";
    
    my $store = Sourcing::Plugin::Memory.new;
    $store.use;
    
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

MAIN();

