package dev.orderflow.apitests.smoke;

import dev.orderflow.apitests.support.TestApi;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.awaitility.Awaitility.await;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;

/**
 * Maintainer smoke test: the stack is up and the admin endpoints work. Not a
 * model answer for any topic.
 */
class StackSmokeTest {

    @Test
    void shouldListSeedProductsWhenStackIsUp() {
        given(TestApi.spec())
                .get("/api/products")
                .then().statusCode(200)
                .body("$", hasSize(greaterThanOrEqualTo(10)));
    }

    @Test
    void shouldConfirmOrderWhenProductIsCreatedThroughAdmin() {
        String productId = TestApi.createProduct("Smoke " + UUID.randomUUID(), 1_000, 3)
                .then().statusCode(201)
                .extract().path("id");

        String orderId = given(TestApi.spec())
                .body(Map.of("customerEmail", "smoke-" + UUID.randomUUID() + "@example.com",
                        "items", List.of(Map.of("productId", productId, "quantity", 1))))
                .post("/api/orders")
                .then().statusCode(201)
                .extract().path("id");

        await().atMost(Duration.ofSeconds(20)).untilAsserted(() ->
                given(TestApi.spec())
                        .get("/api/orders/{id}", orderId)
                        .then().statusCode(200)
                        .body("status", equalTo("CONFIRMED")));
    }
}
