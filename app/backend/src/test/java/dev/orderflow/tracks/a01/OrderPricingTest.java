package dev.orderflow.tracks.a01;

import dev.orderflow.domain.OrderItem;
import dev.orderflow.domain.OrderPricing;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Model branch: an example of the expected shape of a unit test, NOT a
 * solution of A-01. It covers only the simplest rules; the boundaries and the
 * rounding of the discount are left for you.
 *
 * Every test follows Arrange, Act, Assert and checks one behaviour, and its
 * name says the expected result and the condition:
 * should<Result>When<Condition>.
 */
@QuarkusTest
class OrderPricingTest {

    @Inject
    OrderPricing pricing;

    @Test
    void shouldReturnZeroWhenOrderHasNoItems() {
        // Arrange
        List<OrderItem> items = List.of();

        // Act
        long total = pricing.totalInCents(items);

        // Assert
        assertThat(total).isZero();
    }

    @Test
    void shouldMultiplyQuantityByUnitPriceWhenItemHasSeveralUnits() {
        List<OrderItem> items = List.of(new OrderItem("p-1", 3, 1_250));

        long total = pricing.totalInCents(items);

        assertThat(total).isEqualTo(3_750);
    }

    @Test
    void shouldAddEveryItemWhenOrderHasSeveralItems() {
        List<OrderItem> items = List.of(new OrderItem("p-1", 2, 1_000), new OrderItem("p-2", 1, 500));

        long total = pricing.totalInCents(items);

        assertThat(total).isEqualTo(2_500);
    }
}
