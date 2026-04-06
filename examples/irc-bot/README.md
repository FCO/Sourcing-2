# IRC Bot Example with Sourcing

This example demonstrates how to build an IRC bot using the Sourcing event sourcing library in Raku. It showcases aggregations, projections, and sagas working together to manage IRC channel state, user karma, command aliases, and multi-channel broadcasts.

## Overview

The IRC bot example implements:

- **ChannelAggregate**: Manages IRC channel state (joins, parts, messages, topic)
- **UserAggregate**: Manages user state (login, logout, karma, aliases)
- **KarmaProjection**: Tracks karma scores for users
- **AliasProjection**: Tracks command aliases
- **ChannelStatsProjection**: Tracks channel statistics
- **BroadcastSaga**: Orchestrates broadcasting messages across channels

## Directory Structure

```
examples/irc-bot/
├── config.toml              # Bot configuration
├── lib/
│   └── Sourcing/
│       └── Example/
│           └── IRCBot/
│               ├── Events.rakumod       # All event definitions
│               ├── Config.rakumod        # Configuration loader
│               ├── Aggregates/
│               │   ├── ChannelAggregate.rakumod
│               │   └── UserAggregate.rakumod
│               ├── Projections/
│               │   ├── KarmaProjection.rakumod
│               │   ├── AliasProjection.rakumod
│               │   └── ChannelStatsProjection.rakumod
│               └── Sagas/
│                   └── BroadcastSaga.rakumod
└── t/
    └── 01-irc-bot.rakutest  # Test suite
```

## Installation

This example is part of the Sourcing library. To run it:

```bash
# Install dependencies
zef install --/test --test-depends --deps-only .

# Run the tests
mi6 test t/01-irc-bot.rakutest
```

Or run all tests:

```bash
mi6 test
```

## Usage

### Configuration

Edit `config.toml` to configure the bot:

```toml
[nickname]
value = "sourcing-bot"

[server]
value = "localhost"

[port]
value = 6667

[channels]
value = ["#general", "#random", "#testing"]

[karma]
enabled = true
min = -10
max = 10

[alias]
enabled = true

[broadcast]
timeout = 60
max-channels = 50
```

### Loading Configuration

```raku
use Sourcing::Example::IRCBot::Config;

# Load from file
my $config = Config.new: :file("config.toml");

# Or use defaults
my $config = Config.new;
```

### Creating Aggregates

```raku
use Sourcing;
use Sourcing::Plugin::Memory;
use Sourcing::Example::IRCBot::Aggregates::ChannelAggregate;

# Setup storage
my $memory = Sourcing::Plugin::Memory.new;
$memory.use;

# Create a channel aggregate
my $channel = sourcing ChannelAggregate, :channel("#general");

# Join a user
$channel.join-channel: :user("alice");

# Send a message
$channel.receive-message: :user("alice"), :message("Hello world!");
```

### Using Projections

```raku
use Sourcing::Example::IRCBot::Projections::KarmaProjection;

# Track karma
my $karma = sourcing KarmaProjection, :target("alice");
say $karma.status;  # "0 (neutral)"

# Apply karma increase
my $event = KarmaIncreased.new(
    :target("alice"),
    :changed-by("bob"),
    :amount(1),
    :changed-at(DateTime.now)
);
$karma.apply($event);

say $karma.status;  # "1 (good)"
```

### Running a Broadcast Saga

```raku
use Sourcing::Example::IRCBot::Sagas::BroadcastSaga;

my $saga = sourcing BroadcastSaga, :saga-id("broadcast-1");
$saga.start:
    :initiator("alice"),
    :message("Hello from the bot!"),
    :channels["#general", "#random"];

# The saga will:
# 1. Send the message to each channel
# 2. Track successful sends
# 3. If any send fails, rollback all previous sends
# 4. Emit completion event
```

## Architecture

### Aggregations

Aggregations are the write model. They handle commands and emit events:

- **ChannelAggregate**: Manages channel state
- **UserAggregate**: Manages user state

### Projections

Projections are the read model. They consume events and build read models:

- **KarmaProjection**: Tracks user karma scores
- **AliasProjection**: Tracks command aliases
- **ChannelStatsProjection**: Tracks channel statistics

### Sagas

Sagas coordinate multi-step processes with compensation for rollback:

- **BroadcastSaga**: Broadcasts messages to multiple channels with automatic rollback on failure

## Testing

The test suite (`t/01-irc-bot.rakutest`) covers:

1. Configuration loading (defaults and file)
2. ChannelAggregate operations (join, part, message, topic)
3. UserAggregate operations (login, logout, karma, aliases)
4. KarmaProjection (score tracking, status, reset)
5. AliasProjection (set, remove, active check)
6. ChannelStatsProjection (message counts, top users, topic)
7. BroadcastSaga (broadcast, rollback)
8. End-to-end scenario

Run tests:

```bash
mi6 test t/01-irc-bot.rakutest
```

## Events

### Channel Events

- `ChannelJoined`: User joins a channel
- `ChannelParted`: User leaves a channel
- `ChannelMessage`: Message sent to channel
- `ChannelTopicChanged`: Channel topic changed

### User Events

- `UserLogin`: User connects
- `UserLogout`: User disconnects
- `NickChanged`: User changes nickname
- `KarmaIncreased`: User gains karma
- `KarmaDecreased`: User loses karma
- `KarmaReset`: User karma reset to zero
- `AliasSet`: Command alias created
- `AliasRemoved`: Command alias removed

### Broadcast Events

- `BroadcastStarted`: Broadcast saga initiated
- `BroadcastChannelSent`: Message sent to channel
- `BroadcastChannelFailed`: Send failed
- `BroadcastCompleted`: All channels processed
- `BroadcastRolledBack`: Compensation executed

## Key Concepts

### Event Sourcing

All state changes are stored as events. Aggregates rebuild their state by replaying events from the event store.

### Projections vs Aggregations

- **Aggregations** (write model): Handle commands, emit events, enforce business rules
- **Projections** (read model): Consume events, build read models for querying

### Sagas

Sagas manage long-running processes that span multiple aggregations. They track success/failure and execute compensation (rollback) actions when failures occur.

## Extending the Example

To add new functionality:

1. **Define events** in `Events.rakumod`
2. **Update aggregates** to emit events in commands
3. **Create projections** to build read models
4. **Add tests** to verify behavior

For example, to add user ignore functionality:

1. Add `UserIgnored` and `UserUnignored` events
2. Add `ignore-user` and `unignore-user` commands to `UserAggregate`
3. Create an `IgnoreListProjection` to track ignored users
4. Update command handlers to check the ignore list
