package dev.orderflow.domain;

/** One line of an order. The unit price is copied from the product when the order is created. */
public record OrderItem(String productId, int quantity, long unitPriceInCents) {

    public long subtotalInCents() {
        return quantity * unitPriceInCents;
    }
}
