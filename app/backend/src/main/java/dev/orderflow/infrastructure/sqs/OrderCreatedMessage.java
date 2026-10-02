package dev.orderflow.infrastructure.sqs;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import dev.orderflow.domain.OrderCreated;

import java.time.Instant;

/**
 * JSON format of {@link OrderCreated} on the order-created queue:
 * {@code {"orderId": "...", "totalInCents": 1234, "occurredAt": "2026-01-01T00:00:00Z"}}.
 */
public final class OrderCreatedMessage {

    private static final ObjectMapper JSON = new ObjectMapper();

    private OrderCreatedMessage() {
    }

    public static String toJson(OrderCreated event) {
        ObjectNode node = JSON.createObjectNode();
        node.put("orderId", event.orderId());
        node.put("totalInCents", event.totalInCents());
        node.put("occurredAt", event.occurredAt().toString());
        return node.toString();
    }

    /** @throws IllegalArgumentException when the body is not a valid OrderCreated message */
    public static OrderCreated fromJson(String body) {
        try {
            JsonNode node = JSON.readTree(body);
            String orderId = node.path("orderId").asText(null);
            String occurredAt = node.path("occurredAt").asText(null);
            if (orderId == null || occurredAt == null || !node.path("totalInCents").canConvertToLong()) {
                throw new IllegalArgumentException("Incomplete OrderCreated message: " + body);
            }
            return new OrderCreated(orderId, node.path("totalInCents").asLong(), Instant.parse(occurredAt));
        } catch (JsonProcessingException | java.time.format.DateTimeParseException e) {
            throw new IllegalArgumentException("Malformed OrderCreated message: " + body, e);
        }
    }
}
