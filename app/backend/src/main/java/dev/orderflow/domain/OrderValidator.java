package dev.orderflow.domain;

import java.util.List;
import java.util.regex.Pattern;

/** Validates an order request before any product is looked up. */
public class OrderValidator {

    public static final int MIN_QUANTITY = 1;
    public static final int MAX_QUANTITY = 10;

    private static final Pattern EMAIL =
            Pattern.compile("^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}$");

    /** A requested line: product and quantity, before prices are known. */
    public record RequestedItem(String productId, int quantity) {
    }

    public void validate(String customerEmail, List<RequestedItem> items) {
        if (customerEmail == null || !EMAIL.matcher(customerEmail).matches()) {
            throw invalid("customerEmail must be a valid e-mail address.");
        }
        if (items == null || items.isEmpty()) {
            throw invalid("An order must have at least 1 item.");
        }
        for (RequestedItem item : items) {
            if (item == null || item.productId() == null || item.productId().isBlank()) {
                throw invalid("Every item must have a productId.");
            }
            if (item.quantity() < MIN_QUANTITY || item.quantity() > MAX_QUANTITY) {
                throw invalid("quantity must be between " + MIN_QUANTITY + " and " + MAX_QUANTITY + ".");
            }
        }
    }

    private static DomainException invalid(String message) {
        return new DomainException(ErrorCode.VALIDATION_ERROR, message);
    }
}
