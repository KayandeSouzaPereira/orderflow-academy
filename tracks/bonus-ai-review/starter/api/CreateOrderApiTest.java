package dev.orderflow.apitests.tracks.bonus;

import dev.orderflow.apitests.support.TestApi;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.lessThan;
import static org.hamcrest.Matchers.notNullValue;

/** API tests for order creation. Generated with an AI assistant. */
class CreateOrderApiTest {

    private static String createProduct(int stock) {
        return TestApi.createProduct("Bonus " + UUID.randomUUID(), 1_000, stock)
                .then().statusCode(201).extract().path("id");
    }

    private static Map<String, Object> orderBody(String productId, int quantity) {
        return Map.of("customerEmail", "bonus-" + UUID.randomUUID() + "@example.com",
                "items", List.of(Map.of("productId", productId, "quantity", quantity)));
    }

    @Test
    void shouldCreateOrderWhenRequestIsValid() {
        given(TestApi.spec())
                .body(orderBody(createProduct(10), 2))
                .post("/api/orders")
                .then()
                .statusCode(lessThan(300));
    }

    @Test
    void shouldReturnOrderIdWhenOrderIsCreated() {
        given(TestApi.spec())
                .body(orderBody(createProduct(10), 1))
                .post("/api/orders")
                .then()
                .statusCode(lessThan(300))
                .body("id", notNullValue());
    }

    @Test
    void shouldReturnTotalWhenOrderIsCreated() {
        given(TestApi.spec())
                .body(orderBody(createProduct(10), 3))
                .post("/api/orders")
                .then()
                .statusCode(lessThan(300))
                .body("totalInCents", notNullValue());
    }
}
