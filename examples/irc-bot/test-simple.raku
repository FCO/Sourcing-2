#!/usr/bin/env raku
use IRC::Client;

note "Loading...";

CATCH {
    default { 
        note "ERROR: $_"; 
        .trace.print;
    }
}

class Test does IRC::Client::Plugin {
    method irc-connected($e) { 
        note "!!! CONNECTED !!!"; 
    }
    method irc-join($e) { 
        note "!!! JOIN: $e.nick -> $e.channel !!!"; 
    }
    method irc-event($e) { 
        note "=== $e.command ==="; 
    }
}

note "Starting...";
my $bot = IRC::Client.new:
    :host("irc.libera.chat"),
    :port(6667),
    :nick("sourcingTest4"),
    :username("sourcingTest4"),
    :realname("Test Bot"),
    :channels(["#raku"]),
    :debug(True),
    :plugins[Test.new];

note "Running...";
$bot.run;

note "Done!";