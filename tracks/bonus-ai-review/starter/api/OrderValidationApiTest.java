package dev.orderflow.apitests.tracks.bonus;

import dev.orderflow.apitests.support.TestApi;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;

/** API tests for the validation of orders. Generated with an AI assistant. */
class OrderValidationApiTest {

    @Test
    void shouldRejectOrderWhenItemsAreEmpty() {
        given(TestApi.spec())
                .body(Map.of("customerEmail", "bonus@example.com", "items", List.of()))
                .post("/api/orders")
                .then()
                .statusCode(400);
    }

    @Test
    void shouldRejectOrderWhenProductDoesNotExist() {
        given(TestApi.spec())
                .body(Map.of("customerEmail", "bonus@example.com",
                        "items", List.of(Map.of("productId", "missing-" + UUID.randomUUID(), "quantity", 1))))
                .post("/api/orders")
                .then()
                .statusCode(greaterThanOrEqualTo(400));
    }

    @Test
    void shouldRejectOrderWhenEmailIsInvalid() {
        String productId = TestApi.createProduct("Bonus " + UUID.randomUUID(), 1_000, 5)
                .then().statusCode(201).extract().path("id");

        given(TestApi.spec())
                .body(Map.of("customerEmail", "not-an-email",
                        "items", List.of(Map.of("productId", productId, "quantity", 1))))
                .post("/api/orders")
                .then()
                .statusCode(400);
    }
}
