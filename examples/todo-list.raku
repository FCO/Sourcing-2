#!/usr/bin/env raku
use v6.d;
use lib '.';
use lib '..';
use Sourcing;
use Sourcing::Plugin::Memory;
use TodoList;

Sourcing::Plugin::Memory.use;

say "=== Todo List Example ===";

my $todo = sourcing TodoList, :1todo-id;

$todo.add: "Learn Raku";
say "After adding 'Learn Raku': items added";

$todo.add: "Write tests";
say "After adding 'Write tests': items added";

$todo.complete;
$todo.^update;
say "After completing one: done";

$todo.complete;
$todo.^update;
say "After completing another: done";

$todo.cleanup;
$todo.^update;
say "After cleanup (remove completed): cleaned";
say "Completed count: {$todo.completed-count}";

say "\nDone!";