package dev.orderflow.exercises;

import dev.orderflow.exercises.Model.Order;
import dev.orderflow.exercises.Model.Product;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Twelve short exercises (topic B-01). Replace each
 * {@code throw new UnsupportedOperationException(...)} with your code.
 * Do not change the method signatures: the review calls them.
 */
public final class Exercises {

    private Exercises() {
    }

    /** 1. Total of an order: sum of quantity x unit price of every line. */
    public static long totalInCents(Order order) {
        throw new UnsupportedOperationException("Exercise 1");
    }

    /** 2. Names of the products with stock above zero, in alphabetical order. */
    public static List<String> namesInStock(List<Product> products) {
        throw new UnsupportedOperationException("Exercise 2");
    }

    /** 3. How many orders there are of each status (statuses without orders are left out). */
    public static Map<Model.Status, Long> countByStatus(List<Order> orders) {
        throw new UnsupportedOperationException("Exercise 3");
    }

    /** 4. The cheapest product, or an empty Optional when the list is empty. */
    public static Optional<Product> cheapest(List<Product> products) {
        throw new UnsupportedOperationException("Exercise 4");
    }

    /** 5. Formats cents as "BRL 12.34" (two decimals, no thousands separator): 123456 -> "BRL 1234.56". */
    public static String formatCents(long cents) {
        throw new UnsupportedOperationException("Exercise 5");
    }

    /**
     * 6. Reads a quantity typed by a user. Returns it when it is a whole number
     * from 1 to 10 (spaces around it are fine); otherwise throws an
     * IllegalArgumentException whose message contains the text received.
     */
    public static int parseQuantity(String text) {
        throw new UnsupportedOperationException("Exercise 6");
    }

    /** 7. True when the e-mail has one "@", text before it, and a domain with a dot after it. Null is invalid. */
    public static boolean isValidEmail(String email) {
        throw new UnsupportedOperationException("Exercise 7");
    }

    /** 8. Orders of one customer; the e-mail comparison ignores upper/lower case. Keeps the original order. */
    public static List<Order> ordersOf(List<Order> orders, String customerEmail) {
        throw new UnsupportedOperationException("Exercise 8");
    }

    /** 9. Units sold per product id, counting only CONFIRMED orders. */
    public static Map<String, Integer> unitsSoldByProduct(List<Order> orders) {
        throw new UnsupportedOperationException("Exercise 9");
    }

    /** 10. E-mail of the customer who spent most in CONFIRMED orders, or empty when there is none. */
    public static Optional<String> bestCustomer(List<Order> orders) {
        throw new UnsupportedOperationException("Exercise 10");
    }

    /** 11. Splits products into pages of {@code pageSize} (the last page may be smaller). pageSize below 1 throws IllegalArgumentException. */
    public static List<List<Product>> pages(List<Product> products, int pageSize) {
        throw new UnsupportedOperationException("Exercise 11");
    }

    /**
     * 12. Cancels an order: returns a new Order with status CANCELLED (the
     * original is not changed). Only PENDING orders can be cancelled; any
     * other status throws IllegalStateException.
     */
    public static Order cancel(Order order) {
        throw new UnsupportedOperationException("Exercise 12");
    }
}
