package dev.orderflow.infrastructure.dynamodb;

import dev.orderflow.application.port.ProductRepository;
import dev.orderflow.domain.Product;
import dev.orderflow.infrastructure.config.OrderflowConfig;
import jakarta.enterprise.context.ApplicationScoped;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.dynamodb.model.ScanRequest;
import software.amazon.awssdk.services.dynamodb.model.UpdateItemRequest;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static dev.orderflow.infrastructure.dynamodb.AttributeValues.getN;
import static dev.orderflow.infrastructure.dynamodb.AttributeValues.getS;
import static dev.orderflow.infrastructure.dynamodb.AttributeValues.n;
import static dev.orderflow.infrastructure.dynamodb.AttributeValues.s;

/**
 * Products table. Item attributes: id (key), name, description, priceInCents,
 * stock, imageKey. Stock changes use conditional updates, so two concurrent
 * orders can never sell the same last unit.
 */
@ApplicationScoped
public class DynamoProductRepository implements ProductRepository {

    private final DynamoDbClient dynamo;
    private final String table;

    public DynamoProductRepository(DynamoDbClient dynamo, OrderflowConfig config) {
        this.dynamo = dynamo;
        this.table = config.dynamodb().productsTable();
    }

    @Override
    public List<Product> findAll() {
        return dynamo.scanPaginator(ScanRequest.builder().tableName(table).build())
                .items().stream()
                .map(DynamoProductRepository::toProduct)
                .toList();
    }

    @Override
    public Optional<Product> findById(String id) {
        Map<String, AttributeValue> item = dynamo.getItem(GetItemRequest.builder()
                .tableName(table)
                .key(key(id))
                .consistentRead(true)
                .build()).item();
        return item == null || item.isEmpty() ? Optional.empty() : Optional.of(toProduct(item));
    }

    @Override
    public void save(Product product) {
        dynamo.putItem(PutItemRequest.builder().tableName(table).item(toItem(product)).build());
    }

    @Override
    public boolean reserveStock(String productId, int quantity) {
        try {
            dynamo.updateItem(UpdateItemRequest.builder()
                    .tableName(table)
                    .key(key(productId))
                    .updateExpression("SET stock = stock - :q")
                    .conditionExpression("attribute_exists(id) AND stock >= :q")
                    .expressionAttributeValues(Map.of(":q", n(quantity)))
                    .build());
            return true;
        } catch (ConditionalCheckFailedException e) {
            return false;
        }
    }

    @Override
    public void releaseStock(String productId, int quantity) {
        try {
            dynamo.updateItem(UpdateItemRequest.builder()
                    .tableName(table)
                    .key(key(productId))
                    .updateExpression("SET stock = stock + :q")
                    .conditionExpression("attribute_exists(id)")
                    .expressionAttributeValues(Map.of(":q", n(quantity)))
                    .build());
        } catch (ConditionalCheckFailedException e) {
            // Product was removed meanwhile: nothing to give back.
        }
    }

    @Override
    public boolean setStock(String productId, int stock) {
        try {
            dynamo.updateItem(UpdateItemRequest.builder()
                    .tableName(table)
                    .key(key(productId))
                    .updateExpression("SET stock = :s")
                    .conditionExpression("attribute_exists(id)")
                    .expressionAttributeValues(Map.of(":s", n(stock)))
                    .build());
            return true;
        } catch (ConditionalCheckFailedException e) {
            return false;
        }
    }

    private static Map<String, AttributeValue> key(String id) {
        return Map.of("id", s(id));
    }

    static Map<String, AttributeValue> toItem(Product product) {
        Map<String, AttributeValue> item = new HashMap<>();
        item.put("id", s(product.id()));
        item.put("name", s(product.name()));
        if (product.description() != null) {
            item.put("description", s(product.description()));
        }
        item.put("priceInCents", n(product.priceInCents()));
        item.put("stock", n(product.stock()));
        if (product.imageKey() != null) {
            item.put("imageKey", s(product.imageKey()));
        }
        return item;
    }

    static Product toProduct(Map<String, AttributeValue> item) {
        return new Product(
                getS(item, "id"),
                getS(item, "name"),
                getS(item, "description"),
                getN(item, "priceInCents"),
                (int) getN(item, "stock"),
                getS(item, "imageKey"));
    }
}
