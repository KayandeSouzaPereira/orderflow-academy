package dev.orderflow.domain;

/**
 * Valid order transitions: PENDING -> CONFIRMED and PENDING -> CANCELLED.
 * Anything else is rejected.
 */
public class OrderStateMachine {

    public boolean canTransition(OrderStatus from, OrderStatus to) {
        return from == OrderStatus.PENDING
                && (to == OrderStatus.CONFIRMED || to == OrderStatus.CANCELLED);
    }

    public void ensureCanTransition(OrderStatus from, OrderStatus to) {
        if (!canTransition(from, to)) {
            throw new DomainException(ErrorCode.INVALID_ORDER_TRANSITION,
                    "Order cannot change from " + from + " to " + to + ".");
        }
    }
}
