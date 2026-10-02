package dev.orderflow.tracks.a01;

import dev.orderflow.domain.OrderItem;
import dev.orderflow.domain.OrderPricing;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Three badly written tests. Copy this file to
 * app/backend/src/test/java/dev/orderflow/tracks/a01/ and fix each one.
 * Keep the class name: the review looks for it.
 */
class OrderPricingStarterTest {

    private final OrderPricing pricing = new OrderPricing();

    @Test
    void test1() {
        long total = pricing.totalInCents(List.of(new OrderItem("p-1", 2, 1_000)));
        assertEquals(2_000, total);
    }

    @Test
    void shouldComputeTotalWhenOrderHasItems() {
        pricing.totalInCents(List.of(new OrderItem("p-1", 1, 60_000)));
    }

    @Test
    void shouldApplyDiscountAndRoundDown() {
        assertEquals(54_000, pricing.totalInCents(List.of(new OrderItem("p-1", 1, 60_000))));
        assertEquals(45_008, pricing.totalInCents(List.of(new OrderItem("p-1", 1, 50_009))));
    }
}
