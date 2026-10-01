package dev.orderflow.domain;

/**
 * Machine-readable error codes. The API layer maps each code to an HTTP status;
 * the domain only says what went wrong.
 */
public enum ErrorCode {
    VALIDATION_ERROR,
    PRODUCT_NOT_FOUND,
    ORDER_NOT_FOUND,
    OUT_OF_STOCK,
    INVALID_ORDER_TRANSITION,
    INVOICE_NOT_AVAILABLE,
    IMAGE_NOT_AVAILABLE
}
