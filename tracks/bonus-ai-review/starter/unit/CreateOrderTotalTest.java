package dev.orderflow.tracks.bonus;

import dev.orderflow.application.CreateOrderUseCase;
import dev.orderflow.application.CreateOrderUseCase.Command;
import dev.orderflow.application.port.EventPublisher;
import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.application.port.ProductRepository;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderItem;
import dev.orderflow.domain.OrderPricing;
import dev.orderflow.domain.OrderValidator;
import dev.orderflow.domain.OrderValidator.RequestedItem;
import dev.orderflow.support.TestData;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Checks the total calculated when an order is created. Generated with an AI assistant. */
class CreateOrderTotalTest {

    private ProductRepository productRepository;
    private CreateOrderUseCase useCase;
    private final OrderPricing pricing = new OrderPricing();

    @BeforeEach
    void setUp() {
        productRepository = mock(ProductRepository.class);
        when(productRepository.reserveStock(anyString(), anyInt())).thenReturn(true);
        useCase = new CreateOrderUseCase(productRepository, mock(OrderRepository.class), mock(EventPublisher.class),
                new OrderValidator(), pricing, () -> "order-1", TestData.fixedClock());
    }

    private void givenProduct(String id, long priceInCents) {
        when(productRepository.findById(id))
                .thenReturn(Optional.of(TestData.aProduct().withId(id).withPriceInCents(priceInCents).build()));
    }

    @Test
    void shouldCalculateTotalWhenOrderHasSeveralItems() {
        givenProduct("p-1", 20_000);
        givenProduct("p-2", 5_000);
        Command command = new Command("ana@example.com",
                List.of(new RequestedItem("p-1", 3), new RequestedItem("p-2", 1)));

        Order order = useCase.execute(command);

        long expectedTotal = pricing.totalInCents(List.of(new OrderItem("p-1", 3, 20_000), new OrderItem("p-2", 1, 5_000)));
        assertEquals(expectedTotal, order.totalInCents());
    }

    @Test
    void shouldCalculateTotalWhenOrderIsSmall() {
        givenProduct("p-1", 1_500);
        Command command = new Command("ana@example.com", List.of(new RequestedItem("p-1", 2)));

        Order order = useCase.execute(command);

        long expectedTotal = pricing.totalInCents(List.of(new OrderItem("p-1", 2, 1_500)));
        assertEquals(expectedTotal, order.totalInCents());
    }
}
