package dev.orderflow.api.dto;

import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderItem;
import dev.orderflow.domain.OrderStatus;

import java.time.Instant;
import java.util.List;

public record OrderResponse(
        String id,
        String customerEmail,
        List<Item> items,
        long totalInCents,
        OrderStatus status,
        String invoiceKey,
        Instant createdAt,
        Instant updatedAt) {

    public record Item(String productId, int quantity, long unitPriceInCents) {

        static Item from(OrderItem item) {
            return new Item(item.productId(), item.quantity(), item.unitPriceInCents());
        }
    }

    public static OrderResponse from(Order order) {
        return new OrderResponse(order.id(), order.customerEmail(),
                order.items().stream().map(Item::from).toList(),
                order.totalInCents(), order.status(), order.invoiceKey(),
                order.createdAt(), order.updatedAt());
    }
}
