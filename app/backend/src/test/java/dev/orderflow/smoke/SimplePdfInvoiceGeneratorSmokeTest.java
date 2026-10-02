package dev.orderflow.smoke;

import dev.orderflow.infrastructure.invoice.SimplePdfInvoiceGenerator;
import dev.orderflow.support.TestData;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

class SimplePdfInvoiceGeneratorSmokeTest {

    @Test
    void shouldProducePdfDocumentWhenOrderHasItems() {
        byte[] pdf = new SimplePdfInvoiceGenerator().generate(
                TestData.anOrder().withId("order-42").withItem("product-1", 2, 1_050).build());

        String text = new String(pdf, StandardCharsets.US_ASCII);
        assertThat(text).startsWith("%PDF-1.4").endsWith("%%EOF\n");
        assertThat(text).contains("Order: order-42", "Total: BRL 21.00");
    }
}
