package dev.orderflow.tracks.bonus;

import dev.orderflow.application.CreateOrderUseCase;
import dev.orderflow.application.CreateOrderUseCase.Command;
import dev.orderflow.application.port.EventPublisher;
import dev.orderflow.application.port.IdGenerator;
import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.application.port.ProductRepository;
import dev.orderflow.domain.DomainException;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderCreated;
import dev.orderflow.domain.OrderStatus;
import dev.orderflow.domain.OrderValidator.RequestedItem;
import dev.orderflow.domain.Product;
import dev.orderflow.support.TestData;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Unit tests for CreateOrderUseCase, generated with an AI assistant. */
@QuarkusTest
class CreateOrderUseCaseTest {

    @Inject
    CreateOrderUseCase useCase;

    @InjectMock
    ProductRepository productRepository;

    @InjectMock
    OrderRepository orderRepository;

    @InjectMock
    EventPublisher eventPublisher;

    @InjectMock
    IdGenerator idGenerator;

    @BeforeEach
    void setUp() {
        when(idGenerator.newId()).thenReturn("order-1");
        QuarkusMock.installMockForType(TestData.fixedClock(), Clock.class);
    }

    private Product givenProduct(String id, long priceInCents) {
        Product product = TestData.aProduct().withId(id).withPriceInCents(priceInCents).build();
        when(productRepository.findById(id)).thenReturn(Optional.of(product));
        when(productRepository.reserveStock(id, 2)).thenReturn(true);
        return product;
    }

    @Test
    void shouldCreateOrderWhenRequestIsValid() {
        givenProduct("p-1", 1_000);
        Command command = new Command("ana@example.com", List.of(new RequestedItem("p-1", 2)));

        Order order = useCase.execute(command);

        assertNotNull(order);
        assertEquals(OrderStatus.PENDING, order.status());
        verify(orderRepository).save(any(Order.class));
    }

    @Test
    void shouldPublishEventWhenOrderIsSaved() {
        givenProduct("p-1", 1_000);
        Command command = new Command("ana@example.com", List.of(new RequestedItem("p-1", 2)));

        useCase.execute(command);

        verify(eventPublisher).publish(any(OrderCreated.class));
    }

    @Test
    void shouldThrowExceptionWhenProductIsNotFound() {
        when(productRepository.findById("missing")).thenReturn(Optional.empty());
        Command command = new Command("ana@example.com", List.of(new RequestedItem("missing", 1)));

        assertThrows(DomainException.class, () -> useCase.execute(command));
    }
}
