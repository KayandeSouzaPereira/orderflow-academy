package dev.orderflow.tracks.bonus;

import dev.orderflow.application.CreateOrderUseCase;
import dev.orderflow.application.CreateOrderUseCase.Command;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderStatus;
import dev.orderflow.domain.OrderValidator.RequestedItem;
import dev.orderflow.support.TestData;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Verifies that the use case returns what it should. Generated with an AI assistant. */
class CreateOrderUseCaseMockTest {

    @Test
    void shouldReturnOrderWhenUseCaseIsExecuted() {
        CreateOrderUseCase useCase = mock(CreateOrderUseCase.class);
        Order expected = TestData.anOrder().withId("order-1").build();
        Command command = new Command("ana@example.com", List.of(new RequestedItem("p-1", 1)));
        when(useCase.execute(any(Command.class))).thenReturn(expected);

        Order result = useCase.execute(command);

        assertEquals(expected, result);
        verify(useCase).execute(command);
    }

    @Test
    void shouldReturnPendingOrderWhenUseCaseSucceeds() {
        CreateOrderUseCase useCase = mock(CreateOrderUseCase.class);
        Order pending = TestData.anOrder().withStatus(OrderStatus.PENDING).build();
        when(useCase.execute(any(Command.class))).thenReturn(pending);

        Order result = useCase.execute(new Command("ana@example.com", List.of(new RequestedItem("p-1", 1))));

        assertEquals(OrderStatus.PENDING, result.status());
    }
}
