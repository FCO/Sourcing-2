use v6.e.PREVIEW;

use Sourcing::Saga::Events;

=begin pod

=head1 NAME

Sourcing::Saga - Role for saga classes in event sourcing

=head1 DESCRIPTION

This role is automatically composed into classes declared with C<saga>.
Sagas are long-running multi-step business processes that coordinate commands
across multiple aggregations. They maintain state machines, track compensating
transactions for rollback, and support timeout handling.

=end pod

unit role Sourcing::Saga;

has Pair  @.timeout-schedule = [];
has Hash  $!timeout-handlers = {};
has Callable @!undo-blocks = [];

method timeout-handlers() { $!timeout-handlers }

=begin pod

=head2 method start

Creates a new saga and emits a SagaCreated event to initialize the saga in the event store.

=end pod

method start() {
	my %ids = self.^projection-id-pairs;
	my $saga-id-attr = %ids.keys[0];
	my $saga-id = self."$saga-id-attr"();
	my $event = Sourcing::Saga::Events::SagaCreated.new: 
		:$saga-id,
		saga-type => self.WHAT.^name,
		aggregation-ids => %();
	$*SourcingConfig.emit: $event, :type(self.WHAT), :ids(%ids);
}

multi method apply(Sourcing::Saga::Events::TimeOutScheduled $e) {
	my $handler-name = $e.handler-name ~~ Pair ?? $e.handler-name.value !! $e.handler-name;
	$!timeout-handlers{$handler-name} = $e.scheduled-at;
	@.timeout-schedule.push: Pair.new($e.scheduled-at, Set.new($handler-name));
}

multi method apply(Sourcing::Saga::Events::TimedOut $e) {
	my $handler-name = $e.handler-name ~~ Pair ?? $e.handler-name.value !! $e.handler-name;
	if $!timeout-handlers{$handler-name}:exists && self.^can($handler-name) {
		self."$handler-name"();
	}
}

=begin pod

=head1 METHODS

=head2 method undo

Registers a callable block to be executed during rollback. The block
receives the aggregate instance as its topic (via C<*>) and should
perform the reversal of the corresponding action.

=head3 Parameters

=head4 C<Callable $block> — A callable (block or lambda) that takes an aggregate as topic

=head3 Example

  method withdraw-money(Int $amount) {
      $!account.withdrew: $amount;
      self.undo: *.reverse-withdraw: $amount;
  }

=end pod

method undo(Callable $block) {
	@!undo-blocks.push: $block
}

=begin pod

=head2 method timeout-in

Schedules a timeout to call a method on the saga. If no method name is provided,
defaults to calling C<rollback>.

=head3 Parameters

=head4 C<Str $method-name> — The name of the handler method to call when timeout fires (default: 'rollback')

=head4 C<*%params> — Named arguments passed to L<DateTime::Duration/"later"> to compute the timeout

=end pod

method timeout-in(Str $method-name = 'rollback', *%params) {
	my $scheduled-at = DateTime.now.later: |%params;
	$!timeout-handlers{$method-name} = $scheduled-at;
	@.timeout-schedule.push: Pair.new($scheduled-at, Set.new($method-name));
	self.emit-timeout-scheduled: :$method-name, :$scheduled-at;
}

=begin pod

=head2 method rollback

Executes all registered undo blocks in reverse order and clears the undo block stack.

=end pod

method rollback() {
	# Execute undo blocks in reverse order (LIFO)
	while @!undo-blocks {
		my $block = @!undo-blocks.pop;
		$block();
	}
	@!undo-blocks = [];
}

=begin pod

=head2 method verify-timeouts

Checks scheduled timeouts and emits Sourcing::Saga::Events::TimedOut events for any that have fired.
Should be called periodically (e.g., every 10 seconds) by an external scheduler.

=end pod

method verify-timeouts() {
	my @to-fire;
	for @.timeout-schedule {
		last if .key > DateTime.now;
		@to-fire.push: .value;
	}
	for @to-fire -> $set {
		for $set.list -> $pair {
			self.emit-timed-out($pair.key);
		}
	}
	@.timeout-schedule .= grep: { .key > DateTime.now }
}

=begin pod

=head2 method cancel-timeout

Cancels a scheduled timeout by name.

=head3 Parameters

=head4 C<Str $method-name> — The name of the timeout handler to cancel

=end pod

method cancel-timeout(Str $method-name) {
	$!timeout-handlers{$method-name}:delete;
	@.timeout-schedule .= grep: { .value.Set{$method-name}:!exists }
}

=begin pod

=head2 method emit-timeout-scheduled

Internal method to emit Sourcing::Saga::Events::TimeOutScheduled event.
Used by timeout-in to persist timeout scheduling.

=end pod

method emit-timeout-scheduled(Str :$method-name, DateTime :$scheduled-at) {
	my %ids = self.^projection-id-pairs;
	my $saga-id-attr = %ids.keys[0];
	my $saga-id = self."$saga-id-attr"();
	my $event = Sourcing::Saga::Events::TimeOutScheduled.new: :$saga-id, :$method-name, :$scheduled-at;
	$*SourcingConfig.emit: $event,
		:type(self.WHAT),
		:ids(%ids),
		:current-version(self.current-version);
}

=begin pod

=head2 method emit-timed-out

Internal method to emit Sourcing::Saga::Events::TimedOut event.

=end pod

method emit-timed-out(Str $handler-name) {
	my %ids = self.^projection-id-pairs;
	my $saga-id-attr = %ids.keys[0];
	my $saga-id = self."$saga-id-attr"();
	my $event = Sourcing::Saga::Events::TimedOut.new: :$saga-id, handler-name => $handler-name;
	$*SourcingConfig.emit: $event,
		:type(self.WHAT),
		:ids(%ids),
		:current-version(self.current-version);
}

=begin pod

=head2 method current-version

Returns the current version of the saga from the event stream.

=end pod

method current-version() {
	my $attr = self.^attributes.first: *.name eq '$!__current-version__';
	$attr.get_value(self) // -1
}

=begin pod

=head2 method lookup

Retrieves a saga by ID from the event store.

=head3 Parameters

=head4 C<Sourcing::Saga:U $type> — The saga type to look up

=head4 C<*%ids> — Named arguments for the saga's identity attributes

=head3 Returns

A new saga instance with all events applied.

=end pod

method lookup(Sourcing::Saga:U $type: *%ids) {
	my %map{Mu:U} = $type.^handled-events-map;
	my $*SourcingReplay = True;
	my @initial-events = $*SourcingConfig.get-events-after: -1, %ids, %map;
	
	my $new = $type.new: |%ids, :@initial-events;
	$new.^attributes.first(*.name eq '$!__current-version__').set_value: $new, @initial-events.elems - 1;
	
	$*SourcingConfig.store-cached-data: $new, :last-id(@initial-events.elems - 1);
	$new
}

=begin pod

=head2 method send-command

Sends a command to an aggregate. Emits a command event to the event store
directed at the specified aggregate type.

=head3 Parameters

=head4 C<Mu $aggregate-type> — The type of the aggregate to send the command to

=head4 C<%ids> — A hash of identity attribute names to values for the aggregate

=head4 C<Mu $command> — The command object to emit

=end pod

method send-command(Mu $aggregate-type, %ids, Mu $command) {
	$*SourcingConfig.emit: $command,
		:type($aggregate-type),
		:ids(%ids),
		:current-version(self.current-version)
}

=begin pod

=head2 method bind-aggregate

Binds an aggregate reference to the saga and emits a SagaAggregationBound event
to track the relationship in the event store.

=head3 Parameters

=head4 C<Str $attr-name> — The name of the attribute storing the aggregate reference

=head4 C<Mu $aggregate-type> — The type of the aggregate

=head4 C<%ids> — A hash of identity attribute names to values for the aggregate

=end pod

method bind-aggregate(Str $attr-name, Mu $aggregate-type, %ids) {
	my %saga-ids = self.^projection-id-pairs;
	my $saga-id-attr = %saga-ids.keys[0];
	my $saga-id = self."$saga-id-attr"();

	my $event = Sourcing::Saga::Events::SagaAggregationBound.new:
		:$saga-id,
		attribute-name => $attr-name,
		aggregation-type => $aggregate-type.^name,
		:ids(%ids);

	$*SourcingConfig.emit: $event,
		:type(self.WHAT),
		:ids(%saga-ids),
		:current-version(self.current-version);
}
