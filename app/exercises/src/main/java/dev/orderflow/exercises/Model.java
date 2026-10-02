package dev.orderflow.exercises;

import java.util.List;

/**
 * The data the exercises work on: a tiny copy of OrderFlow's domain.
 * Do not change these records.
 */
public final class Model {

    private Model() {
    }

    public record Product(String id, String name, long priceInCents, int stock) {
    }

    public record OrderLine(String productId, int quantity, long unitPriceInCents) {
    }

    public enum Status {
        PENDING,
        CONFIRMED,
        CANCELLED
    }

    public record Order(String id, String customerEmail, Status status, List<OrderLine> lines) {

        public Order {
            lines = List.copyOf(lines);
        }
    }
}
