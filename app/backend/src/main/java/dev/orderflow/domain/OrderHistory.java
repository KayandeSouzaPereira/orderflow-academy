package dev.orderflow.domain;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * The status history of an order, oldest first. Every order starts as PENDING
 * when it is created; an order that is no longer PENDING has one more entry,
 * its current status, at the time of the last update.
 */
public class OrderHistory {

    /** One step of the history. */
    public record Entry(OrderStatus status, Instant at) {
    }

    public List<Entry> of(Order order) {
        List<Entry> entries = new ArrayList<>();
        entries.add(new Entry(OrderStatus.PENDING, order.createdAt()));
        if (order.status() != OrderStatus.PENDING) {
            entries.add(new Entry(order.status(), order.updatedAt()));
        }
        return List.copyOf(entries);
    }
}
