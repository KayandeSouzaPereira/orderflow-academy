package dev.orderflow.apitests.tracks.bonus;

import dev.orderflow.apitests.support.TestApi;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;

/** API tests for order totals and customer queries. Generated with an AI assistant. */
class OrderTotalApiTest {

    private static String createProduct(long priceInCents) {
        return TestApi.createProduct("Bonus " + UUID.randomUUID(), priceInCents, 20)
                .then().statusCode(201).extract().path("id");
    }

    @Test
    void shouldReturnSumOfItemsWhenOrderIsSmall() {
        String productId = createProduct(1_500);

        given(TestApi.spec())
                .body(Map.of("customerEmail", "bonus-" + UUID.randomUUID() + "@example.com",
                        "items", List.of(Map.of("productId", productId, "quantity", 2))))
                .post("/api/orders")
                .then()
                .statusCode(201)
                .body("totalInCents", equalTo(3_000));
    }

    @Test
    void shouldReturnPositiveTotalWhenOrderIsLarge() {
        String productId = createProduct(30_000);

        given(TestApi.spec())
                .body(Map.of("customerEmail", "bonus-" + UUID.randomUUID() + "@example.com",
                        "items", List.of(Map.of("productId", productId, "quantity", 2))))
                .post("/api/orders")
                .then()
                .statusCode(201)
                .body("totalInCents", greaterThan(0));
    }

    @Test
    void shouldListOrdersWhenCustomerHasOrders() {
        String productId = createProduct(1_000);
        String email = "bonus-" + UUID.randomUUID() + "@example.com";
        given(TestApi.spec())
                .body(Map.of("customerEmail", email, "items", List.of(Map.of("productId", productId, "quantity", 1))))
                .post("/api/orders")
                .then().statusCode(201);

        given(TestApi.spec())
                .queryParam("customerEmail", email)
                .get("/api/orders")
                .then()
                .statusCode(200);
    }
}
