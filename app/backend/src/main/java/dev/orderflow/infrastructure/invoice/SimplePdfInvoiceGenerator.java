package dev.orderflow.infrastructure.invoice;

import dev.orderflow.application.port.InvoiceGenerator;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderItem;
import jakarta.enterprise.context.ApplicationScoped;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Writes a one-page PDF by hand (no PDF library): a title, the order data and
 * one line per item. Good enough for a fictional store.
 */
@ApplicationScoped
public class SimplePdfInvoiceGenerator implements InvoiceGenerator {

    @Override
    public byte[] generate(Order order) {
        List<String> lines = new ArrayList<>();
        lines.add("OrderFlow - Invoice");
        lines.add("");
        lines.add("Order: " + order.id());
        lines.add("Customer: " + order.customerEmail());
        lines.add("Date: " + order.createdAt());
        lines.add("");
        for (OrderItem item : order.items()) {
            lines.add(item.quantity() + " x " + item.productId() + " @ " + money(item.unitPriceInCents())
                    + " = " + money(item.subtotalInCents()));
        }
        lines.add("");
        lines.add("Total: " + money(order.totalInCents()));
        return render(lines);
    }

    static String money(long cents) {
        return String.format(Locale.ROOT, "BRL %d.%02d", cents / 100, cents % 100);
    }

    private static byte[] render(List<String> lines) {
        StringBuilder content = new StringBuilder("BT\n/F1 12 Tf\n16 TL\n50 790 Td\n");
        for (String line : lines) {
            content.append('(').append(escape(line)).append(") Tj T*\n");
        }
        content.append("ET\n");

        String[] objects = {
                "<< /Type /Catalog /Pages 2 0 R >>",
                "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
                        + "/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
                "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
                "<< /Length " + content.length() + " >>\nstream\n" + content + "endstream",
        };

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        write(out, "%PDF-1.4\n");
        long[] offsets = new long[objects.length];
        for (int i = 0; i < objects.length; i++) {
            offsets[i] = out.size();
            write(out, (i + 1) + " 0 obj\n" + objects[i] + "\nendobj\n");
        }
        long xref = out.size();
        StringBuilder trailer = new StringBuilder("xref\n0 " + (objects.length + 1) + "\n0000000000 65535 f \n");
        for (long offset : offsets) {
            trailer.append(String.format(Locale.ROOT, "%010d 00000 n \n", offset));
        }
        trailer.append("trailer\n<< /Size ").append(objects.length + 1).append(" /Root 1 0 R >>\n")
                .append("startxref\n").append(xref).append("\n%%EOF\n");
        write(out, trailer.toString());
        return out.toByteArray();
    }

    /** Keeps printable ASCII only and escapes PDF string delimiters. */
    private static String escape(String text) {
        StringBuilder result = new StringBuilder();
        for (char c : text.toCharArray()) {
            if (c == '(' || c == ')' || c == '\\') {
                result.append('\\').append(c);
            } else if (c >= 32 && c < 127) {
                result.append(c);
            } else {
                result.append('?');
            }
        }
        return result.toString();
    }

    private static void write(ByteArrayOutputStream out, String text) {
        out.writeBytes(text.getBytes(StandardCharsets.US_ASCII));
    }
}
