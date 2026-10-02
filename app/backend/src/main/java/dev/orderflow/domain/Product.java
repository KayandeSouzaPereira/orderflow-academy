package dev.orderflow.domain;

/** A catalog product. Prices are integers in cents. */
public record Product(
        String id,
        String name,
        String description,
        long priceInCents,
        int stock,
        String imageKey) {

    public Product withStock(int newStock) {
        return new Product(id, name, description, priceInCents, newStock, imageKey);
    }
}
