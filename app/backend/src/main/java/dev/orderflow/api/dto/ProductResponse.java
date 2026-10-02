package dev.orderflow.api.dto;

import dev.orderflow.domain.Product;

public record ProductResponse(String id, String name, String description, long priceInCents, int stock) {

    public static ProductResponse from(Product product) {
        return new ProductResponse(product.id(), product.name(), product.description(),
                product.priceInCents(), product.stock());
    }
}
