#!/usr/bin/env raku
use IRC::Client;

class TestPlugin does IRC::Client::Plugin {
    method irc-connected($e) { say "CONNECTED!"; }
    method irc-join($e)     { say "JOIN: {$e.nick} -> {$e.channel}"; }
    method irc-privmsg-channel($e) { say "MSG: {$e.nick}: {$e.text}"; }
    method irc-event($e)   { say "EVENT: {$e.command}"; }
}

say "Starting...";
my $bot = IRC::Client.new:
    :host("irc.libera.chat"),
    :port(6697),
    :nick("sourcing-bot-xyz"),
    :username("sourcingbotxyz"),
    :realname("Sourcing Bot"),
    :channels(["#raku"]),
    :debug(True),
    :ssl(True),
    :plugins[TestPlugin.new];

say "Running...";
$bot.run;