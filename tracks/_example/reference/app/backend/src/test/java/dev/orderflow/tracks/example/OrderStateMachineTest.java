package dev.orderflow.tracks.example;

import dev.orderflow.domain.DomainException;
import dev.orderflow.domain.ErrorCode;
import dev.orderflow.domain.OrderStateMachine;
import dev.orderflow.domain.OrderStatus;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Reference solution of the example topic. */
class OrderStateMachineTest {

    private final OrderStateMachine stateMachine = new OrderStateMachine();

    @ParameterizedTest(name = "{0} -> {1}")
    @CsvSource({"PENDING, CONFIRMED", "PENDING, CANCELLED"})
    void shouldAllowTransitionWhenOrderIsPendingAndTargetIsFinal(OrderStatus from, OrderStatus to) {
        assertThat(stateMachine.canTransition(from, to)).isTrue();
        assertThatCode(() -> stateMachine.ensureCanTransition(from, to)).doesNotThrowAnyException();
    }

    @ParameterizedTest(name = "{0} -> {1}")
    @CsvSource({
            "PENDING, PENDING",
            "CONFIRMED, PENDING", "CONFIRMED, CONFIRMED", "CONFIRMED, CANCELLED",
            "CANCELLED, PENDING", "CANCELLED, CONFIRMED", "CANCELLED, CANCELLED"})
    void shouldRejectTransitionWhenItIsNotPendingToFinal(OrderStatus from, OrderStatus to) {
        assertThat(stateMachine.canTransition(from, to)).isFalse();
        assertThatThrownBy(() -> stateMachine.ensureCanTransition(from, to))
                .isInstanceOf(DomainException.class)
                .extracting(e -> ((DomainException) e).code())
                .isEqualTo(ErrorCode.INVALID_ORDER_TRANSITION);
    }

    @Test
    void shouldNameBothStatusesWhenTransitionIsRejected() {
        assertThatThrownBy(() -> stateMachine.ensureCanTransition(OrderStatus.CONFIRMED, OrderStatus.CANCELLED))
                .hasMessageContaining("CONFIRMED")
                .hasMessageContaining("CANCELLED");
    }
}
