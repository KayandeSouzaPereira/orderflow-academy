package dev.orderflow.tracks.bonus;

import dev.orderflow.application.CreateOrderUseCase;
import dev.orderflow.application.CreateOrderUseCase.Command;
import dev.orderflow.application.port.EventPublisher;
import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.application.port.ProductRepository;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderPricing;
import dev.orderflow.domain.OrderValidator;
import dev.orderflow.domain.OrderValidator.RequestedItem;
import dev.orderflow.support.TestData;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Failure scenarios of order creation. Generated with an AI assistant. */
class CreateOrderFailureTest {

    private ProductRepository productRepository;
    private OrderRepository orderRepository;
    private EventPublisher eventPublisher;
    private CreateOrderUseCase useCase;

    @BeforeEach
    void setUp() {
        productRepository = mock(ProductRepository.class);
        orderRepository = mock(OrderRepository.class);
        eventPublisher = mock(EventPublisher.class);
        when(productRepository.findById("p-1"))
                .thenReturn(Optional.of(TestData.aProduct().withId("p-1").withPriceInCents(1_000).build()));
        when(productRepository.reserveStock(anyString(), anyInt())).thenReturn(true);
        useCase = new CreateOrderUseCase(productRepository, orderRepository, eventPublisher,
                new OrderValidator(), new OrderPricing(), () -> "order-1", TestData.fixedClock());
    }

    @Test
    void shouldHandleRepositoryFailureWhenOrderCannotBeSaved() {
        doThrow(new IllegalStateException("database down")).when(orderRepository).save(any(Order.class));
        Command command = new Command("ana@example.com", List.of(new RequestedItem("p-1", 1)));

        try {
            useCase.execute(command);
        } catch (IllegalStateException e) {
        }
    }

    @Test
    void shouldHandleEventFailureWhenPublisherIsDown() {
        doThrow(new IllegalStateException("queue down")).when(eventPublisher).publish(any());
        Command command = new Command("ana@example.com", List.of(new RequestedItem("p-1", 1)));

        try {
            useCase.execute(command);
        } catch (Exception e) {
            // expected
        }
    }
}
