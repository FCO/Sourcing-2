#!/usr/bin/env raku
use IRC::Client;

say "Loading IRC::Client...";

class TestPlugin does IRC::Client::Plugin {
    method irc-connected($e) { 
        say "!!! CONNECTED to {$e.server} !!!"; 
    }
    method irc-join($e) { 
        say "!!! JOIN: {$e.nick} -> {$e.channel} !!!"; 
    }
    method irc-event($e) { 
        say "!!! {$e.command} !!!"; 
    }
}

say "Creating bot...";
my $bot = IRC::Client.new:
    :host("irc.libera.chat"),
    :port(6697),
    :nick("sourcing-test-999"),
    :username("sourcetest999"),
    :realname("Sourcing Test"),
    :channels(["#raku"]),
    :ssl(True),
    :plugins[TestPlugin.new];

say "Running bot...";
$bot.run;
say "Bot finished!";