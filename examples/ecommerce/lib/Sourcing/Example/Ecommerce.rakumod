use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Example::Ecommerce - E-commerce example demonstrating Sourcing concepts

=head1 SYNOPSIS

    use Sourcing::Example::Ecommerce;
    use Sourcing::Plugin::Memory;
    
    # Set up the event store
    my $store = Sourcing::Plugin::Memory.use;
    
    # Create and use aggregates
    my $order = Sourcing::Example::Ecommerce::OrderAggregate.new: :order-id<ORD-001>;
    $order.create-order: :customer-id<CUST-001>, :items{ 'ITEM-A' => { :quantity(2), :unit-price(29.99) } };
    
    # Read via projection
    my $order-view = sourcing Sourcing::Example::Ecommerce::OrderProjection, :order-id<ORD-001>;
    say $order-view.status;  # 'pending'

=head1 DESCRIPTION

This module provides a complete e-commerce domain example showing how to use
Sourcing for event sourcing. It includes:

=item B<Aggregates> - Order, Inventory, Payment aggregates that handle commands
=item B<Projections> - Read-optimized views for each aggregate type
=item B<Sagas> - Order fulfillment saga coordinating multiple aggregates
=item B<Events> - Domain events for orders, inventory, and payments

=head1 MODULES

=item Sourcing::Example::Ecommerce::Events - Event definitions
=item Sourcing::Example::Ecommerce::OrderAggregate - Order command handling
=item Sourcing::Example::Ecommerce::InventoryAggregate - Inventory command handling
=item Sourcing::Example::Ecommerce::PaymentAggregate - Payment command handling
=item Sourcing::Example::Ecommerce::OrderProjection - Order read model
=item Sourcing::Example::Ecommerce::InventoryProjection - Inventory read model
=item Sourcing::Example::Ecommerce::PaymentProjection - Payment read model
=item Sourcing::Example::Ecommerce::OrderFulfillmentSaga - Multi-step order processing

=head1 CONCEPTS DEMONSTRATED

=item Projection with C<is projection>
=item Aggregation with C<is aggregation>
=item Saga with C<saga>
=item Command methods with C<is command>
=item Projection IDs with C<is projection-id>
=item State-based saga guards with C<is on-state>
=item Optimistic locking with C<current-version>
=item Plugins - EventStore::Memory, StateCache::Memory

=end pod

unit module Sourcing::Example::Ecommerce;

use Sourcing::Example::Ecommerce::Events;
use Sourcing::Example::Ecommerce::OrderAggregate;
use Sourcing::Example::Ecommerce::InventoryAggregate;
use Sourcing::Example::Ecommerce::PaymentAggregate;
use Sourcing::Example::Ecommerce::OrderProjection;
use Sourcing::Example::Ecommerce::InventoryProjection;
use Sourcing::Example::Ecommerce::PaymentProjection;
use Sourcing::Example::Ecommerce::OrderFulfillmentSaga;

# Export key types
our (
    OrderAggregate,
    InventoryAggregate, 
    PaymentAggregate,
    OrderProjection,
    InventoryProjection,
    PaymentProjection,
    OrderFulfillmentSaga
) is export;