package dev.orderflow.support;

import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderItem;
import dev.orderflow.domain.OrderStatus;
import dev.orderflow.domain.Product;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Builders for domain objects with sensible defaults. Override only what the
 * test is about:
 *
 * <pre>{@code
 * Product product = TestData.aProduct().withStock(0).build();
 * Order order = TestData.anOrder().withItem("p-1", 2, 1_000).withStatus(OrderStatus.CONFIRMED).build();
 * }</pre>
 */
public final class TestData {

    /** Fixed instant used by default, so tests never depend on the real clock. */
    public static final Instant NOW = Instant.parse("2026-01-15T10:00:00Z");

    private TestData() {
    }

    public static Clock fixedClock() {
        return Clock.fixed(NOW, ZoneOffset.UTC);
    }

    public static String uniqueId(String prefix) {
        return prefix + "-" + UUID.randomUUID();
    }

    public static ProductBuilder aProduct() {
        return new ProductBuilder();
    }

    public static OrderBuilder anOrder() {
        return new OrderBuilder();
    }

    public static final class ProductBuilder {
        private String id = uniqueId("product");
        private String name = "Test product";
        private String description = "A product created by a test.";
        private long priceInCents = 10_000;
        private int stock = 10;
        private String imageKey = null;

        public ProductBuilder withId(String value) {
            id = value;
            return this;
        }

        public ProductBuilder withName(String value) {
            name = value;
            return this;
        }

        public ProductBuilder withPriceInCents(long value) {
            priceInCents = value;
            return this;
        }

        public ProductBuilder withStock(int value) {
            stock = value;
            return this;
        }

        public ProductBuilder withImageKey(String value) {
            imageKey = value;
            return this;
        }

        public Product build() {
            return new Product(id, name, description, priceInCents, stock, imageKey);
        }
    }

    public static final class OrderBuilder {
        private String id = uniqueId("order");
        private String customerEmail = "customer@example.com";
        private final List<OrderItem> items = new ArrayList<>();
        private Long totalInCents = null;
        private OrderStatus status = OrderStatus.PENDING;
        private String invoiceKey = null;
        private Instant createdAt = NOW;

        public OrderBuilder withId(String value) {
            id = value;
            return this;
        }

        public OrderBuilder withCustomerEmail(String value) {
            customerEmail = value;
            return this;
        }

        public OrderBuilder withItem(String productId, int quantity, long unitPriceInCents) {
            items.add(new OrderItem(productId, quantity, unitPriceInCents));
            return this;
        }

        /** Overrides the total. By default it is the plain sum of the items, without discount. */
        public OrderBuilder withTotalInCents(long value) {
            totalInCents = value;
            return this;
        }

        public OrderBuilder withStatus(OrderStatus value) {
            status = value;
            return this;
        }

        public OrderBuilder withInvoiceKey(String value) {
            invoiceKey = value;
            return this;
        }

        public OrderBuilder withCreatedAt(Instant value) {
            createdAt = value;
            return this;
        }

        public Order build() {
            List<OrderItem> finalItems = items.isEmpty()
                    ? List.of(new OrderItem("product-1", 1, 10_000))
                    : List.copyOf(items);
            long total = totalInCents != null ? totalInCents
                    : finalItems.stream().mapToLong(OrderItem::subtotalInCents).sum();
            return new Order(id, customerEmail, finalItems, total, status, invoiceKey, createdAt, createdAt);
        }
    }
}
