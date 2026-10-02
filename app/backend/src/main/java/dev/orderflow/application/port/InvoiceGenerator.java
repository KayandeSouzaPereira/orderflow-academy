package dev.orderflow.application.port;

import dev.orderflow.domain.Order;

public interface InvoiceGenerator {

    /** Renders the invoice of {@code order} as a PDF document. */
    byte[] generate(Order order);
}
