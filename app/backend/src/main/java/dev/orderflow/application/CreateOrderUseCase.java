package dev.orderflow.application;

import dev.orderflow.application.port.EventPublisher;
import dev.orderflow.application.port.IdGenerator;
import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.application.port.ProductRepository;
import dev.orderflow.domain.DomainException;
import dev.orderflow.domain.ErrorCode;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderCreated;
import dev.orderflow.domain.OrderItem;
import dev.orderflow.domain.OrderPricing;
import dev.orderflow.domain.OrderStatus;
import dev.orderflow.domain.OrderValidator;
import dev.orderflow.domain.OrderValidator.RequestedItem;
import dev.orderflow.domain.Product;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Creates an order: validates it, reserves stock, saves it as PENDING and
 * publishes {@link OrderCreated}. The event is published only after the order
 * is saved, and reserved stock is given back if anything fails before that.
 */
public class CreateOrderUseCase {

    public record Command(String customerEmail, List<RequestedItem> items) {
    }

    private final ProductRepository products;
    private final OrderRepository orders;
    private final EventPublisher events;
    private final OrderValidator validator;
    private final OrderPricing pricing;
    private final IdGenerator ids;
    private final Clock clock;

    public CreateOrderUseCase(ProductRepository products, OrderRepository orders, EventPublisher events,
                              OrderValidator validator, OrderPricing pricing, IdGenerator ids, Clock clock) {
        this.products = products;
        this.orders = orders;
        this.events = events;
        this.validator = validator;
        this.pricing = pricing;
        this.ids = ids;
        this.clock = clock;
    }

    public Order execute(Command command) {
        validator.validate(command.customerEmail(), command.items());

        Map<String, Integer> quantityByProduct = quantityByProduct(command.items());
        Map<String, Product> productsById = loadProducts(quantityByProduct);

        reserveStock(quantityByProduct);

        Order order = buildOrder(command, productsById);
        try {
            orders.save(order);
        } catch (RuntimeException e) {
            releaseStock(quantityByProduct);
            throw e;
        }

        events.publish(new OrderCreated(order.id(), order.totalInCents(), order.createdAt()));
        return order;
    }

    /** Merges lines of the same product, so stock is reserved once per product. */
    private static Map<String, Integer> quantityByProduct(List<RequestedItem> items) {
        Map<String, Integer> result = new LinkedHashMap<>();
        for (RequestedItem item : items) {
            result.merge(item.productId(), item.quantity(), Integer::sum);
        }
        return result;
    }

    private Map<String, Product> loadProducts(Map<String, Integer> quantityByProduct) {
        Map<String, Product> result = new LinkedHashMap<>();
        for (String productId : quantityByProduct.keySet()) {
            Product product = products.findById(productId)
                    .orElseThrow(() -> new DomainException(ErrorCode.PRODUCT_NOT_FOUND,
                            "Product " + productId + " does not exist."));
            result.put(productId, product);
        }
        return result;
    }

    private void reserveStock(Map<String, Integer> quantityByProduct) {
        Map<String, Integer> reserved = new LinkedHashMap<>();
        for (Map.Entry<String, Integer> entry : quantityByProduct.entrySet()) {
            if (!products.reserveStock(entry.getKey(), entry.getValue())) {
                releaseStock(reserved);
                throw new DomainException(ErrorCode.OUT_OF_STOCK,
                        "Not enough stock for product " + entry.getKey() + ".");
            }
            reserved.put(entry.getKey(), entry.getValue());
        }
    }

    private void releaseStock(Map<String, Integer> quantityByProduct) {
        quantityByProduct.forEach(products::releaseStock);
    }

    private Order buildOrder(Command command, Map<String, Product> productsById) {
        List<OrderItem> items = new ArrayList<>();
        for (RequestedItem requested : command.items()) {
            long unitPrice = productsById.get(requested.productId()).priceInCents();
            items.add(new OrderItem(requested.productId(), requested.quantity(), unitPrice));
        }
        Instant now = clock.instant();
        return new Order(ids.newId(), command.customerEmail(), items, pricing.totalInCents(items),
                OrderStatus.PENDING, null, now, now);
    }
}
