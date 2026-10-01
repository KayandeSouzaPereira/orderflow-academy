package dev.orderflow.domain;

import java.time.Instant;
import java.util.List;

/** An order. Immutable: state changes return a new instance. */
public record Order(
        String id,
        String customerEmail,
        List<OrderItem> items,
        long totalInCents,
        OrderStatus status,
        String invoiceKey,
        Instant createdAt,
        Instant updatedAt) {

    public Order {
        items = List.copyOf(items);
    }

    public Order withStatus(OrderStatus newStatus, Instant at) {
        return new Order(id, customerEmail, items, totalInCents, newStatus, invoiceKey, createdAt, at);
    }

    public Order confirmedWithInvoice(String newInvoiceKey, Instant at) {
        return new Order(id, customerEmail, items, totalInCents, OrderStatus.CONFIRMED, newInvoiceKey, createdAt, at);
    }
}
