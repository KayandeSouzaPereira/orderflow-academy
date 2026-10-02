package dev.orderflow.tracks.bonus;

import dev.orderflow.application.ProcessOrderCreatedUseCase;
import dev.orderflow.application.ProcessOrderCreatedUseCase.Outcome;
import dev.orderflow.application.port.InvoiceGenerator;
import dev.orderflow.application.port.InvoiceStorage;
import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderCreated;
import dev.orderflow.domain.OrderStateMachine;
import dev.orderflow.support.TestData;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Unit tests for the order processor. Generated with an AI assistant. */
class ProcessOrderCreatedUseCaseTest {

    private OrderRepository orderRepository;
    private InvoiceGenerator invoiceGenerator;
    private InvoiceStorage invoiceStorage;
    private ProcessOrderCreatedUseCase useCase;

    @BeforeEach
    void setUp() {
        orderRepository = mock(OrderRepository.class);
        invoiceGenerator = mock(InvoiceGenerator.class);
        invoiceStorage = mock(InvoiceStorage.class);
        useCase = new ProcessOrderCreatedUseCase(orderRepository, invoiceGenerator, invoiceStorage,
                new OrderStateMachine(), TestData.fixedClock());
    }

    @Test
    void shouldConfirmOrderWhenOrderIsPending() {
        Order order = TestData.anOrder().withId("order-1").build();
        when(orderRepository.findById("order-1")).thenReturn(Optional.of(order));
        when(invoiceGenerator.generate(any(Order.class))).thenReturn(new byte[] {1, 2, 3});
        when(orderRepository.replaceIfStatus(any(Order.class), any())).thenReturn(true);

        Outcome outcome = useCase.execute(new OrderCreated("order-1", 1_000, TestData.NOW));

        assertEquals(Outcome.CONFIRMED, outcome);
        verify(invoiceStorage).store(eq("invoices/order-1.pdf"), any(byte[].class));
    }

    @Test
    void shouldSkipOrderWhenOrderDoesNotExist() {
        when(orderRepository.findById("missing")).thenReturn(Optional.empty());

        Outcome outcome = useCase.execute(new OrderCreated("missing", 1_000, TestData.NOW));

        assertEquals(Outcome.SKIPPED_ORDER_NOT_FOUND, outcome);
    }
}
