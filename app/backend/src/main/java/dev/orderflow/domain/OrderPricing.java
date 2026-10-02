package dev.orderflow.domain;

import java.util.List;

/**
 * Computes order totals.
 *
 * <p>The total is the sum of quantity x unit price. Orders strictly above
 * {@link #DISCOUNT_THRESHOLD_IN_CENTS} get a {@link #DISCOUNT_PERCENT}% discount,
 * and the discounted total is rounded down to the cent. Negative quantities or
 * prices are rejected, so a total is never negative.
 */
public class OrderPricing {

    public static final long DISCOUNT_THRESHOLD_IN_CENTS = 50_000L;
    public static final int DISCOUNT_PERCENT = 10;

    public long totalInCents(List<OrderItem> items) {
        long subtotal = 0;
        for (OrderItem item : items) {
            if (item.quantity() < 0 || item.unitPriceInCents() < 0) {
                throw new IllegalArgumentException("Quantity and unit price cannot be negative: " + item);
            }
            subtotal += item.subtotalInCents();
        }
        if (subtotal > DISCOUNT_THRESHOLD_IN_CENTS) {
            // Integer division on non-negative values rounds down.
            return subtotal * (100 - DISCOUNT_PERCENT) / 100;
        }
        return subtotal;
    }
}
