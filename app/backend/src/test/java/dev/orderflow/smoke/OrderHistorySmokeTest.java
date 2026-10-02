package dev.orderflow.smoke;

import dev.orderflow.domain.OrderHistory;
import dev.orderflow.domain.OrderStatus;
import dev.orderflow.support.TestData;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** Maintainer smoke test of the history rule. Not a model answer for any topic. */
class OrderHistorySmokeTest {

    @Test
    void shouldListPendingThenCurrentStatusWhenOrderIsNotPending() {
        var order = TestData.anOrder().withStatus(OrderStatus.CONFIRMED).build();

        assertThat(new OrderHistory().of(order))
                .extracting(OrderHistory.Entry::status)
                .containsExactly(OrderStatus.PENDING, OrderStatus.CONFIRMED);
    }

    @Test
    void shouldListOnlyPendingWhenOrderIsPending() {
        assertThat(new OrderHistory().of(TestData.anOrder().build()))
                .extracting(OrderHistory.Entry::status)
                .containsExactly(OrderStatus.PENDING);
    }
}
