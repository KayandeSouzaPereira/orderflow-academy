package dev.orderflow.apitests.tracks.bonus;

import dev.orderflow.apitests.support.TestApi;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;

/** API tests that read and cancel an order. Generated with an AI assistant. */
class OrderQueryApiTest {

    private static String sharedOrderId;

    @Test
    void shouldCreateOrderWhenProductExists() {
        String productId = TestApi.createProduct("Bonus " + UUID.randomUUID(), 1_000, 5)
                .then().statusCode(201).extract().path("id");
        sharedOrderId = given(TestApi.spec())
                .body(Map.of("customerEmail", "bonus-" + UUID.randomUUID() + "@example.com",
                        "items", List.of(Map.of("productId", productId, "quantity", 1))))
                .post("/api/orders")
                .then().statusCode(201).extract().path("id");
    }

    @Test
    void shouldFindOrderWhenItWasCreated() {
        given(TestApi.spec())
                .get("/api/orders/{id}", sharedOrderId)
                .then()
                .statusCode(200)
                .body("id", equalTo(sharedOrderId));
    }

    @Test
    void shouldCancelOrderWhenItIsPending() {
        given(TestApi.spec())
                .post("/api/orders/{id}/cancel", sharedOrderId)
                .then()
                .statusCode(200);
    }
}
