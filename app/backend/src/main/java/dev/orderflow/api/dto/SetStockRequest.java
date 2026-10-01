package dev.orderflow.api.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/** Body of {@code PUT /api/admin/products/{id}/stock}. */
public record SetStockRequest(@NotNull @PositiveOrZero Integer stock) {
}
