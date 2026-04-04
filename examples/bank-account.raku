#!/usr/bin/env raku
use v6.d;
use lib '.';
use lib '..';
use Sourcing;
use Sourcing::Plugin::Memory;
use BankAccount;

Sourcing::Plugin::Memory.use;

say "=== Bank Account Example ===";

my $bank = sourcing BankAccount, :42account-id;
say "Initial balance: \${$bank.balance}";

$bank.deposit: 1000.00;
$bank.^update;
say "After deposit: \${$bank.balance}";

$bank.withdraw: 250.00;
$bank.^update;
say "After withdrawal: \${$bank.balance}";

$bank.withdraw: 100.00;
$bank.^update;
say "After another withdrawal: \${$bank.balance}";
say "Total transactions: {$bank.transaction-count}";

say "\nDone!";