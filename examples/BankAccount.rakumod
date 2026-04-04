use Sourcing;

class MoneyDeposited is export {
    has UInt $.account-id is required;
    has Rat $.amount is required;
}

class MoneyWithdrawn is export {
    has UInt $.account-id is required;
    has Rat $.amount is required;
}

aggregation BankAccount {
    has UInt $.account-id is required is projection-id;
    has Rat $.balance = 0.0;
    has Int $.transaction-count = 0;

    multi method apply(MoneyDeposited $e) {
        $!balance += $e.amount;
        $!transaction-count++;
    }

    multi method apply(MoneyWithdrawn $e) {
        $!balance -= $e.amount;
        $!transaction-count++;
    }

    method deposit(Rat $amount where * > 0) {
        $.money-deposited: amount => $amount;
    }

    method withdraw(Rat $amount where * > 0) {
        die "Insufficient funds" if $!balance < $amount;
        $.money-withdrawn: amount => $amount;
    }
}