package dev.orderflow.apitests.support;

import io.restassured.builder.RequestSpecBuilder;
import io.restassured.config.LogConfig;
import io.restassured.config.RestAssuredConfig;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;

import java.util.LinkedHashMap;
import java.util.Map;

import static io.restassured.RestAssured.given;

/**
 * Entry point for black-box API tests.
 *
 * <ul>
 *   <li>{@link #spec()}: base request (base URL, JSON) for every call.</li>
 *   <li>{@link #createProduct}/{@link #setStock}: shortcuts to the admin
 *       endpoints, to prepare test data without touching the database.</li>
 * </ul>
 *
 * <p>The base URL comes from the {@code API_BASE_URL} environment variable
 * (or the {@code api.base-url} system property); default {@code http://localhost:8080}.
 */
public final class TestApi {

    public static final String DEFAULT_BASE_URL = "http://localhost:8080";

    private TestApi() {
    }

    public static String baseUrl() {
        String fromProperty = System.getProperty("api.base-url");
        if (fromProperty != null && !fromProperty.isBlank()) {
            return fromProperty;
        }
        String fromEnv = System.getenv("API_BASE_URL");
        return fromEnv == null || fromEnv.isBlank() ? DEFAULT_BASE_URL : fromEnv;
    }

    /** Base request: base URL, JSON in and out, request/response logged when a validation fails. */
    public static RequestSpecification spec() {
        return new RequestSpecBuilder()
                .setBaseUri(baseUrl())
                .setContentType(ContentType.JSON)
                .setAccept(ContentType.JSON)
                .setConfig(RestAssuredConfig.config()
                        .logConfig(LogConfig.logConfig().enableLoggingOfRequestAndResponseIfValidationFails()))
                .build();
    }

    /**
     * Creates a product through {@code POST /api/admin/products} and returns the raw response.
     * The admin endpoints must be enabled in the stack (they are in the "full" profile).
     */
    public static Response createProduct(String name, long priceInCents, int stock) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("name", name);
        body.put("description", "Created by an API test.");
        body.put("priceInCents", priceInCents);
        body.put("stock", stock);
        return given(spec()).body(body).post("/api/admin/products");
    }

    /** Overwrites the stock of a product through {@code PUT /api/admin/products/{id}/stock}. */
    public static Response setStock(String productId, int stock) {
        return given(spec()).body(Map.of("stock", stock)).put("/api/admin/products/{id}/stock", productId);
    }
}
