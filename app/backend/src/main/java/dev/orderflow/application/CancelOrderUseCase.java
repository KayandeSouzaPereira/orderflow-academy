package dev.orderflow.application;

import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.application.port.ProductRepository;
import dev.orderflow.domain.DomainException;
import dev.orderflow.domain.ErrorCode;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderItem;
import dev.orderflow.domain.OrderStateMachine;
import dev.orderflow.domain.OrderStatus;

import java.time.Clock;

/** Cancels a PENDING order and gives its stock back. */
public class CancelOrderUseCase {

    private final OrderRepository orders;
    private final ProductRepository products;
    private final OrderStateMachine stateMachine;
    private final Clock clock;

    public CancelOrderUseCase(OrderRepository orders, ProductRepository products,
                              OrderStateMachine stateMachine, Clock clock) {
        this.orders = orders;
        this.products = products;
        this.stateMachine = stateMachine;
        this.clock = clock;
    }

    public Order execute(String orderId) {
        Order order = orders.findById(orderId)
                .orElseThrow(() -> new DomainException(ErrorCode.ORDER_NOT_FOUND,
                        "Order " + orderId + " does not exist."));

        stateMachine.ensureCanTransition(order.status(), OrderStatus.CANCELLED);

        Order cancelled = order.withStatus(OrderStatus.CANCELLED, clock.instant());
        if (!orders.replaceIfStatus(cancelled, OrderStatus.PENDING)) {
            // The processor confirmed it between our read and our write.
            throw new DomainException(ErrorCode.INVALID_ORDER_TRANSITION,
                    "Order " + orderId + " is no longer PENDING.");
        }

        for (OrderItem item : order.items()) {
            products.releaseStock(item.productId(), item.quantity());
        }
        return cancelled;
    }
}
