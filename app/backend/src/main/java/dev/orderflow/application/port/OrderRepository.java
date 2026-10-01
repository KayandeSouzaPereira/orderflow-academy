package dev.orderflow.application.port;

import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderStatus;

import java.util.List;
import java.util.Optional;

public interface OrderRepository {

    /** Inserts a new order. */
    void save(Order order);

    Optional<Order> findById(String id);

    /** Orders of one customer, newest first. */
    List<Order> findByCustomerEmail(String customerEmail);

    /**
     * Replaces the stored order with {@code updated} only if its current status
     * is {@code expectedStatus}. Protects against concurrent cancel/confirm.
     *
     * @return {@code false} when the stored status was different (nothing is changed)
     */
    boolean replaceIfStatus(Order updated, OrderStatus expectedStatus);
}
