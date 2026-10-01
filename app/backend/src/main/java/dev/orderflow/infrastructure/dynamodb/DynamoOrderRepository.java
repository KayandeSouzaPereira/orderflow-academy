package dev.orderflow.infrastructure.dynamodb;

import dev.orderflow.application.port.OrderRepository;
import dev.orderflow.domain.Order;
import dev.orderflow.domain.OrderItem;
import dev.orderflow.domain.OrderStatus;
import dev.orderflow.infrastructure.config.OrderflowConfig;
import jakarta.enterprise.context.ApplicationScoped;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.dynamodb.model.QueryRequest;

import java.time.Instant;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static dev.orderflow.infrastructure.dynamodb.AttributeValues.getN;
import static dev.orderflow.infrastructure.dynamodb.AttributeValues.getS;
import static dev.orderflow.infrastructure.dynamodb.AttributeValues.n;
import static dev.orderflow.infrastructure.dynamodb.AttributeValues.s;

/**
 * Orders table. Item attributes: id (key), customerEmail, items (list of maps
 * with productId, quantity, unitPriceInCents), totalInCents, status, invoiceKey,
 * createdAt, updatedAt (ISO-8601). A global secondary index on customerEmail
 * (sort key createdAt) serves the per-customer query.
 */
@ApplicationScoped
public class DynamoOrderRepository implements OrderRepository {

    private final DynamoDbClient dynamo;
    private final String table;
    private final String customerIndex;

    public DynamoOrderRepository(DynamoDbClient dynamo, OrderflowConfig config) {
        this.dynamo = dynamo;
        this.table = config.dynamodb().ordersTable();
        this.customerIndex = config.dynamodb().ordersByCustomerIndex();
    }

    @Override
    public void save(Order order) {
        dynamo.putItem(PutItemRequest.builder()
                .tableName(table)
                .item(toItem(order))
                .conditionExpression("attribute_not_exists(id)")
                .build());
    }

    @Override
    public Optional<Order> findById(String id) {
        Map<String, AttributeValue> item = dynamo.getItem(GetItemRequest.builder()
                .tableName(table)
                .key(Map.of("id", s(id)))
                .consistentRead(true)
                .build()).item();
        return item == null || item.isEmpty() ? Optional.empty() : Optional.of(toOrder(item));
    }

    @Override
    public List<Order> findByCustomerEmail(String customerEmail) {
        return dynamo.queryPaginator(QueryRequest.builder()
                        .tableName(table)
                        .indexName(customerIndex)
                        .keyConditionExpression("customerEmail = :e")
                        .expressionAttributeValues(Map.of(":e", s(customerEmail)))
                        .build())
                .items().stream()
                .map(DynamoOrderRepository::toOrder)
                .sorted(Comparator.comparing(Order::createdAt).reversed().thenComparing(Order::id))
                .toList();
    }

    @Override
    public boolean replaceIfStatus(Order updated, OrderStatus expectedStatus) {
        try {
            dynamo.putItem(PutItemRequest.builder()
                    .tableName(table)
                    .item(toItem(updated))
                    .conditionExpression("#status = :expected")
                    // "status" is a DynamoDB reserved word.
                    .expressionAttributeNames(Map.of("#status", "status"))
                    .expressionAttributeValues(Map.of(":expected", s(expectedStatus.name())))
                    .build());
            return true;
        } catch (ConditionalCheckFailedException e) {
            return false;
        }
    }

    static Map<String, AttributeValue> toItem(Order order) {
        Map<String, AttributeValue> item = new HashMap<>();
        item.put("id", s(order.id()));
        item.put("customerEmail", s(order.customerEmail()));
        item.put("items", AttributeValue.fromL(order.items().stream().map(DynamoOrderRepository::toItem).toList()));
        item.put("totalInCents", n(order.totalInCents()));
        item.put("status", s(order.status().name()));
        if (order.invoiceKey() != null) {
            item.put("invoiceKey", s(order.invoiceKey()));
        }
        item.put("createdAt", s(order.createdAt().toString()));
        item.put("updatedAt", s(order.updatedAt().toString()));
        return item;
    }

    private static AttributeValue toItem(OrderItem orderItem) {
        return AttributeValue.fromM(Map.of(
                "productId", s(orderItem.productId()),
                "quantity", n(orderItem.quantity()),
                "unitPriceInCents", n(orderItem.unitPriceInCents())));
    }

    static Order toOrder(Map<String, AttributeValue> item) {
        List<OrderItem> items = item.get("items").l().stream()
                .map(AttributeValue::m)
                .map(m -> new OrderItem(getS(m, "productId"), (int) getN(m, "quantity"), getN(m, "unitPriceInCents")))
                .toList();
        return new Order(
                getS(item, "id"),
                getS(item, "customerEmail"),
                items,
                getN(item, "totalInCents"),
                OrderStatus.valueOf(getS(item, "status")),
                getS(item, "invoiceKey"),
                Instant.parse(getS(item, "createdAt")),
                Instant.parse(getS(item, "updatedAt")));
    }
}
