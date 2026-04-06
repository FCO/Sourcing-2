use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::Ecommerce::Events;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::PaymentAggregate - Payment aggregate for e-commerce

=head1 DESCRIPTION

The Payment aggregate manages payment processing. It handles:
- Initiating payments
- Authorizing payments (verifying funds)
- Capturing payments (collecting funds)
- Failing payments
- Refunding payments

=end pod

unit class Sourcing::Example::Ecommerce::PaymentAggregate is aggregation;

has Str $.payment-id is projection-id;
has Str $.order-id;
has Numeric $.amount = 0;
has Str $.method;  # credit-card, debit, paypal
has Str $.status = 'initiated';
has Str $.authorization-code;
has DateTime $.authorized-at;
has DateTime $.captured-at;
has DateTime $.failed-at;
has Numeric $.captured-amount = 0;
has Numeric $.refunded-amount = 0;
has Str $.failure-reason;
has Str $.refund-reason;

=begin pod

=head2 Method apply

Handles all payment events and updates aggregate state.

=end pod

multi method apply(PaymentInitiated $e) {
    $!payment-id = $e.payment-id;
    $!order-id = $e.order-id;
    $!amount = $e.amount;
    $!method = $e.method;
    $!status = $e.status // 'pending';
}

multi method apply(PaymentAuthorized $e) {
    die "Payment must be pending to authorize" unless $!status eq 'pending';
    $!status = 'authorized';
    $!authorization-code = $e.authorization-code;
    $!authorized-at = $e.authorized-at // DateTime.now;
}

multi method apply(PaymentCaptured $e) {
    die "Payment must be authorized to capture" unless $!status eq 'authorized';
    $!status = 'captured';
    $!captured-amount = $e.captured-amount // $!amount;
    $!captured-at = $e.captured-at // DateTime.now;
}

multi method apply(PaymentFailed $e) {
    die "Payment cannot fail in status: $!status" unless $!status eq 'pending' | 'authorized';
    $!status = 'failed';
    $!failure-reason = $e.reason;
    $!failed-at = $e.failed-at // DateTime.now;
}

multi method apply(PaymentRefunded $e) {
    die "Payment must be captured to refund" unless $!status eq 'captured';
    $!refunded-amount += $e.refunded-amount // ($!captured-amount - $!refunded-amount);
    $!refund-reason = $e.reason;
    $!refunded-at = $e.refunded-at // DateTime.now;
    
    # If fully refunded, mark as refunded
    if $!refunded-amount >= $!captured-amount {
        $!status = 'refunded';
    }
}

=begin pod

=head2 Method initiate

Command to initiate a new payment.

=end pod

method initiate(Str :$order-id, Numeric :$amount, Str :$method) {
    $!amount = $amount;
    $!method = $method;
    $!order-id = $order-id;
    
    self.payment-initiated(
        :$payment-id,
        :$order-id,
        :$amount,
        :$method
    );
}

=begin pod

=head2 Method authorize

Command to authorize a payment.

=end pod

method authorize(Str :$authorization-code) {
    die "Payment must be pending to authorize" unless $!status eq 'pending';
    
    self.payment-authorized(
        :$payment-id,
        :$authorization-code,
        :authorized-at(DateTime.now)
    );
}

=begin pod

=head2 Method capture

Command to capture a payment (collect funds).

=end pod

method capture(Numeric :$captured-amount = $!amount) {
    die "Payment must be authorized to capture" unless $!status eq 'authorized';
    
    self.payment-captured(
        :$payment-id,
        :$captured-amount,
        :captured-at(DateTime.now)
    );
}

=begin pod

=head2 Method fail

Command to mark payment as failed.

=end pod

method fail(Str :$reason) {
    die "Payment cannot fail in status: $!status" unless $!status eq 'pending' | 'authorized';
    
    self.payment-failed(
        :$payment-id,
        :$reason,
        :failed-at(DateTime.now)
    );
}

=begin pod

=head2 Method refund

Command to refund a payment.

=end pod

method refund(Numeric :$refunded-amount, Str :$reason) {
    die "Payment must be captured to refund" unless $!status eq 'captured';
    die "Refund amount exceeds captured amount" if $refunded-amount > ($!captured-amount - $!refunded-amount);
    
    self.payment-refunded(
        :$payment-id,
        :$refunded-amount,
        :$reason,
        :refunded-at(DateTime.now)
    );
}