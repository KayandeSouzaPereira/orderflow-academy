package dev.orderflow.infrastructure.dynamodb;

import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

import java.util.Map;

/** Small helpers to read and write DynamoDB attribute values. */
final class AttributeValues {

    private AttributeValues() {
    }

    static AttributeValue s(String value) {
        return AttributeValue.fromS(value);
    }

    static AttributeValue n(long value) {
        return AttributeValue.fromN(Long.toString(value));
    }

    static String getS(Map<String, AttributeValue> item, String name) {
        AttributeValue value = item.get(name);
        return value == null ? null : value.s();
    }

    static long getN(Map<String, AttributeValue> item, String name) {
        AttributeValue value = item.get(name);
        if (value == null || value.n() == null) {
            throw new IllegalStateException("Missing numeric attribute '" + name + "' in " + item.keySet());
        }
        return Long.parseLong(value.n());
    }
}
