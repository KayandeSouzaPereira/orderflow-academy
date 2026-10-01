package dev.orderflow.api.error;

/** The only error body the API returns: {@code {"code": "OUT_OF_STOCK", "message": "..."}}. */
public record ErrorResponse(String code, String message) {
}
