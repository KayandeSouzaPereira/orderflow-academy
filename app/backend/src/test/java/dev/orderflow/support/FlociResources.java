package dev.orderflow.support;

import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeDefinition;
import software.amazon.awssdk.services.dynamodb.model.BillingMode;
import software.amazon.awssdk.services.dynamodb.model.GlobalSecondaryIndex;
import software.amazon.awssdk.services.dynamodb.model.KeySchemaElement;
import software.amazon.awssdk.services.dynamodb.model.KeyType;
import software.amazon.awssdk.services.dynamodb.model.Projection;
import software.amazon.awssdk.services.dynamodb.model.ProjectionType;
import software.amazon.awssdk.services.dynamodb.model.ScalarAttributeType;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.sqs.SqsClient;

import java.net.URI;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Creates an isolated set of OrderFlow resources (two tables, a queue and a
 * bucket) in Floci, all named with the same unique suffix, and returns the
 * {@code orderflow.*} properties that point the application at them.
 */
public final class FlociResources {

    public static final String ORDERS_BY_CUSTOMER_INDEX = "customerEmail-index";

    private FlociResources() {
    }

    public static Map<String, String> create(String endpoint, String region, String accessKey, String secretKey,
                                             String suffix) {
        String productsTable = "products-" + suffix;
        String ordersTable = "orders-" + suffix;
        String queue = "order-created-" + suffix;
        String bucket = "orderflow-" + suffix;

        URI uri = URI.create(endpoint);
        Region awsRegion = Region.of(region);
        StaticCredentialsProvider credentials =
                StaticCredentialsProvider.create(AwsBasicCredentials.create(accessKey, secretKey));

        try (DynamoDbClient dynamo = DynamoDbClient.builder()
                .endpointOverride(uri).region(awsRegion).credentialsProvider(credentials).build();
             SqsClient sqs = SqsClient.builder()
                     .endpointOverride(uri).region(awsRegion).credentialsProvider(credentials).build();
             S3Client s3 = S3Client.builder()
                     .endpointOverride(uri).region(awsRegion).credentialsProvider(credentials)
                     .forcePathStyle(true).build()) {

            createProductsTable(dynamo, productsTable);
            createOrdersTable(dynamo, ordersTable);
            sqs.createQueue(b -> b.queueName(queue));
            s3.createBucket(b -> b.bucket(bucket));
        }

        Map<String, String> config = new LinkedHashMap<>();
        config.put("orderflow.aws.endpoint", endpoint);
        config.put("orderflow.aws.region", region);
        config.put("orderflow.aws.access-key-id", accessKey);
        config.put("orderflow.aws.secret-access-key", secretKey);
        config.put("orderflow.dynamodb.products-table", productsTable);
        config.put("orderflow.dynamodb.orders-table", ordersTable);
        config.put("orderflow.dynamodb.orders-by-customer-index", ORDERS_BY_CUSTOMER_INDEX);
        config.put("orderflow.sqs.order-created-queue", queue);
        config.put("orderflow.s3.bucket", bucket);
        return config;
    }

    private static void createProductsTable(DynamoDbClient dynamo, String table) {
        dynamo.createTable(b -> b
                .tableName(table)
                .attributeDefinitions(attribute("id"))
                .keySchema(key("id", KeyType.HASH))
                .billingMode(BillingMode.PAY_PER_REQUEST));
    }

    private static void createOrdersTable(DynamoDbClient dynamo, String table) {
        dynamo.createTable(b -> b
                .tableName(table)
                .attributeDefinitions(attribute("id"), attribute("customerEmail"), attribute("createdAt"))
                .keySchema(key("id", KeyType.HASH))
                .globalSecondaryIndexes(GlobalSecondaryIndex.builder()
                        .indexName(ORDERS_BY_CUSTOMER_INDEX)
                        .keySchema(key("customerEmail", KeyType.HASH), key("createdAt", KeyType.RANGE))
                        .projection(Projection.builder().projectionType(ProjectionType.ALL).build())
                        .build())
                .billingMode(BillingMode.PAY_PER_REQUEST));
    }

    private static AttributeDefinition attribute(String name) {
        return AttributeDefinition.builder().attributeName(name).attributeType(ScalarAttributeType.S).build();
    }

    private static KeySchemaElement key(String name, KeyType type) {
        return KeySchemaElement.builder().attributeName(name).keyType(type).build();
    }
}
