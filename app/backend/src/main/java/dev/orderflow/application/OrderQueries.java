package dev.orderflow.application;

import dev.orderflow.application.port.InvoiceStorage;
import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.application.port.PresignedUrl;
import dev.orderflow.domain.DomainException;
import dev.orderflow.domain.ErrorCode;
import dev.orderflow.domain.Order;

import java.util.List;

/** Read-side operations on orders. */
public class OrderQueries {

    private final OrderRepository orders;
    private final InvoiceStorage invoiceStorage;

    public OrderQueries(OrderRepository orders, InvoiceStorage invoiceStorage) {
        this.orders = orders;
        this.invoiceStorage = invoiceStorage;
    }

    public Order get(String orderId) {
        return orders.findById(orderId)
                .orElseThrow(() -> new DomainException(ErrorCode.ORDER_NOT_FOUND,
                        "Order " + orderId + " does not exist."));
    }

    public List<Order> listByCustomer(String customerEmail) {
        return orders.findByCustomerEmail(customerEmail);
    }

    public PresignedUrl invoiceUrl(String orderId) {
        Order order = get(orderId);
        if (order.invoiceKey() == null) {
            throw new DomainException(ErrorCode.INVOICE_NOT_AVAILABLE,
                    "Order " + orderId + " has no invoice yet.");
        }
        return invoiceStorage.presign(order.invoiceKey());
    }
}
