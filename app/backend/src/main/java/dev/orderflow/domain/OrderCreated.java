package dev.orderflow.domain;

import java.time.Instant;

/** Event published after an order is saved. */
public record OrderCreated(String orderId, long totalInCents, Instant occurredAt) {
}
