package dev.orderflow.application;

import dev.orderflow.application.port.InvoiceGenerator;
import dev.orderflow.application.port.InvoiceStorage;
import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderCreated;
import dev.orderflow.domain.OrderStateMachine;
import dev.orderflow.domain.OrderStatus;

import java.time.Clock;
import java.util.Optional;

/**
 * Handles {@link OrderCreated}: generates the invoice, stores it under
 * {@code invoices/{orderId}.pdf} and confirms the order.
 *
 * <p>Safe to run more than once for the same event: orders that are no longer
 * PENDING (already confirmed, or cancelled meanwhile) are skipped.
 */
public class ProcessOrderCreatedUseCase {

    public enum Outcome {
        CONFIRMED,
        SKIPPED_NOT_PENDING,
        SKIPPED_ORDER_NOT_FOUND
    }

    private final OrderRepository orders;
    private final InvoiceGenerator invoiceGenerator;
    private final InvoiceStorage invoiceStorage;
    private final OrderStateMachine stateMachine;
    private final Clock clock;

    public ProcessOrderCreatedUseCase(OrderRepository orders, InvoiceGenerator invoiceGenerator,
                                      InvoiceStorage invoiceStorage, OrderStateMachine stateMachine, Clock clock) {
        this.orders = orders;
        this.invoiceGenerator = invoiceGenerator;
        this.invoiceStorage = invoiceStorage;
        this.stateMachine = stateMachine;
        this.clock = clock;
    }

    public static String invoiceKey(String orderId) {
        return "invoices/" + orderId + ".pdf";
    }

    public Outcome execute(OrderCreated event) {
        Optional<Order> found = orders.findById(event.orderId());
        if (found.isEmpty()) {
            return Outcome.SKIPPED_ORDER_NOT_FOUND;
        }
        Order order = found.get();
        if (!stateMachine.canTransition(order.status(), OrderStatus.CONFIRMED)) {
            return Outcome.SKIPPED_NOT_PENDING;
        }

        String key = invoiceKey(order.id());
        invoiceStorage.store(key, invoiceGenerator.generate(order));

        Order confirmed = order.confirmedWithInvoice(key, clock.instant());
        if (!orders.replaceIfStatus(confirmed, OrderStatus.PENDING)) {
            // Cancelled while the invoice was being generated.
            return Outcome.SKIPPED_NOT_PENDING;
        }
        return Outcome.CONFIRMED;
    }
}
