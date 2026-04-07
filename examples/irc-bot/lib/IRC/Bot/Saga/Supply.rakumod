use v6.e.PREVIEW;

use Sourcing;
use IRC::Bot::Channel::Events;
use IRC::Bot::Saga::KarmaHandler;
use IRC::Bot::Saga::AliasHandler;

unit module IRC::Bot::Saga::Supply;

my %channel-callbacks;
my $saga-supply-tap;

sub set-channel-callback(Str $channel, Callable $callback) is export {
    %channel-callbacks{$channel} = $callback;
}

sub clear-channel-callbacks() is export {
    %channel-callbacks = ();
}

sub handle-message(MessageReceived $event, Bool :$verbose = False) is export {
    say "SAGA: MessageReceived in {$event.channel} from {$event.nick}: {$event.message}" if $verbose;
    my $channel = $event.channel;
    my $callback = %channel-callbacks{$channel};

    return unless $callback;

    my $message = $event.message // '';
    my $trimmed-message = $message.trim;
    return unless $trimmed-message.chars;
    return if $trimmed-message.starts-with('!');

    my $karma-saga = sourcing IRC::Bot::Saga::KarmaHandler, :$channel;
    with $karma-saga.apply($event) -> $response {
        $callback($response) if $response.defined;
    }

    my $alias-saga = sourcing IRC::Bot::Saga::AliasHandler, :$channel;
    with $alias-saga.apply($event) -> $response {
        $callback($response) if $response.defined;
    }
}

multi sub start-saga-supply(Supply $supply, Bool :$verbose = False, :$config) is export {
    return $saga-supply-tap if $saga-supply-tap.defined;

    $saga-supply-tap = $supply.tap(-> $event {
        my $*SourcingConfig = $config if $config.defined;
        if $event ~~ MessageReceived {
            handle-message($event, :$verbose);
        }
    });

    $saga-supply-tap
}

multi sub start-saga-supply($config, Bool :$verbose = False) is export {
    return $saga-supply-tap if $saga-supply-tap.defined;

    start-saga-supply($config.supply, :$config, :$verbose)
}

sub stop-saga-supply() is export {
    $saga-supply-tap.close if $saga-supply-tap;
    $saga-supply-tap = Nil;
}
