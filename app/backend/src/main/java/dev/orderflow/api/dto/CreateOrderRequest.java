package dev.orderflow.api.dto;

import dev.orderflow.application.CreateOrderUseCase;
import dev.orderflow.domain.OrderValidator.RequestedItem;

import java.util.List;

/**
 * Body of {@code POST /api/orders}. Validation happens in the domain
 * ({@code OrderValidator}), so this DTO has no constraint annotations.
 */
public record CreateOrderRequest(String customerEmail, List<Item> items) {

    public record Item(String productId, Integer quantity) {
    }

    public CreateOrderUseCase.Command toCommand() {
        List<RequestedItem> requested = items == null ? null : items.stream()
                .map(item -> item == null ? null
                        : new RequestedItem(item.productId(), item.quantity() == null ? 0 : item.quantity()))
                .toList();
        return new CreateOrderUseCase.Command(customerEmail, requested);
    }
}
