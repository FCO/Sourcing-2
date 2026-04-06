use v6.e.PREVIEW;

use Sourcing;
use Sourcing::Example::Ecommerce::Events;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce::PaymentProjection - Payment read model projection

=head1 DESCRIPTION

A projection that builds a read-optimized view of payments. This projection
maintains payment status and history for querying.

=end pod

unit class Sourcing::Example::Ecommerce::PaymentProjection is projection;

has Str $.payment-id is projection-id;
has Str $.order-id;
has Numeric $.amount = 0;
has Str $.method;
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

Updates the projection based on incoming events.

=end pod

multi method apply(PaymentInitiated $e) {
    $!payment-id = $e.payment-id;
    $!order-id = $e.order-id;
    $!amount = $e.amount;
    $!method = $e.method;
    $!status = $e.status // 'pending';
}

multi method apply(PaymentAuthorized $e) {
    $!status = 'authorized';
    $!authorization-code = $e.authorization-code;
    $!authorized-at = $e.authorized-at // DateTime.now;
}

multi method apply(PaymentCaptured $e) {
    $!status = 'captured';
    $!captured-amount = $e.captured-amount // $!amount;
    $!captured-at = $e.captured-at // DateTime.now;
}

multi method apply(PaymentFailed $e) {
    $!status = 'failed';
    $!failure-reason = $e.reason;
    $!failed-at = $e.failed-at // DateTime.now;
}

multi method apply(PaymentRefunded $e) {
    $!refunded-amount += $e.refunded-amount // ($!captured-amount - $!refunded-amount);
    $!refund-reason = $e.reason;
    
    if $!refunded-amount >= $!captured-amount {
        $!status = 'refunded';
    }
}

=begin pod

=head2 Method to-hash

Returns a hash representation for JSON serialization.

=end pod

method to-hash() {
    {
        payment-id => $!payment-id,
        order-id => $!order-id,
        amount => $!amount,
        method => $!method,
        status => $!status,
        authorization-code => $!authorization-code,
        captured-amount => $!captured-amount,
        refunded-amount => $!refunded-amount,
        failure-reason => $!failure-reason,
        refund-reason => $!refund-reason
    }
}