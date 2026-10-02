package dev.orderflow.api.dto;

import dev.orderflow.application.ProductCatalog;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/** Body of {@code POST /api/admin/products}. */
public record CreateProductRequest(
        @NotBlank String name,
        String description,
        @NotNull @PositiveOrZero Long priceInCents,
        @NotNull @PositiveOrZero Integer stock,
        String imageKey) {

    public ProductCatalog.NewProduct toNewProduct() {
        return new ProductCatalog.NewProduct(name, description, priceInCents, stock, imageKey);
    }
}
