package dev.orderflow.tracks.example;

import dev.orderflow.domain.OrderStateMachine;
import dev.orderflow.domain.OrderStatus;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** Calibration: happy path only. Must score below 70. */
class OrderStateMachineTest {

    private final OrderStateMachine stateMachine = new OrderStateMachine();

    @Test
    void shouldAllowConfirmationWhenOrderIsPending() {
        assertThat(stateMachine.canTransition(OrderStatus.PENDING, OrderStatus.CONFIRMED)).isTrue();
    }

    @Test
    void shouldAllowCancellationWhenOrderIsPending() {
        assertThat(stateMachine.canTransition(OrderStatus.PENDING, OrderStatus.CANCELLED)).isTrue();
    }
}
