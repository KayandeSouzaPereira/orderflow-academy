package dev.orderflow.infrastructure.config;

import dev.orderflow.application.CancelOrderUseCase;
import dev.orderflow.application.CreateOrderUseCase;
import dev.orderflow.application.OrderQueries;
import dev.orderflow.application.ProcessOrderCreatedUseCase;
import dev.orderflow.application.ProductCatalog;
import dev.orderflow.application.port.EventPublisher;
import dev.orderflow.application.port.IdGenerator;
import dev.orderflow.application.port.InvoiceGenerator;
import dev.orderflow.application.port.InvoiceStorage;
import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.application.port.ProductImageStorage;
import dev.orderflow.application.port.ProductRepository;
import dev.orderflow.domain.OrderPricing;
import dev.orderflow.domain.OrderStateMachine;
import dev.orderflow.domain.OrderValidator;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Singleton;

import java.time.Clock;
import java.util.UUID;

/**
 * Wires the framework-free domain and application classes into CDI. Keeping
 * the wiring here lets unit tests build those classes with plain {@code new}.
 */
@ApplicationScoped
public class ApplicationBeans {

    @Produces
    @Singleton
    Clock clock() {
        return Clock.systemUTC();
    }

    @Produces
    @Singleton
    IdGenerator idGenerator() {
        return () -> UUID.randomUUID().toString();
    }

    @Produces
    @Singleton
    OrderPricing orderPricing() {
        return new OrderPricing();
    }

    @Produces
    @Singleton
    OrderStateMachine orderStateMachine() {
        return new OrderStateMachine();
    }

    @Produces
    @Singleton
    OrderValidator orderValidator() {
        return new OrderValidator();
    }

    @Produces
    @Singleton
    CreateOrderUseCase createOrderUseCase(ProductRepository products, OrderRepository orders,
                                          EventPublisher events, OrderValidator validator,
                                          OrderPricing pricing, IdGenerator ids, Clock clock) {
        return new CreateOrderUseCase(products, orders, events, validator, pricing, ids, clock);
    }

    @Produces
    @Singleton
    CancelOrderUseCase cancelOrderUseCase(OrderRepository orders, ProductRepository products,
                                          OrderStateMachine stateMachine, Clock clock) {
        return new CancelOrderUseCase(orders, products, stateMachine, clock);
    }

    @Produces
    @Singleton
    ProcessOrderCreatedUseCase processOrderCreatedUseCase(OrderRepository orders, InvoiceGenerator generator,
                                                          InvoiceStorage storage, OrderStateMachine stateMachine,
                                                          Clock clock) {
        return new ProcessOrderCreatedUseCase(orders, generator, storage, stateMachine, clock);
    }

    @Produces
    @Singleton
    OrderQueries orderQueries(OrderRepository orders, InvoiceStorage invoices) {
        return new OrderQueries(orders, invoices);
    }

    @Produces
    @Singleton
    ProductCatalog productCatalog(ProductRepository products, ProductImageStorage images, IdGenerator ids) {
        return new ProductCatalog(products, images, ids);
    }
}
