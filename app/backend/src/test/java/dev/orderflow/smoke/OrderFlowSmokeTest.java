package dev.orderflow.smoke;

import dev.orderflow.support.FlociTestResource;
import io.quarkus.test.common.WithTestResource;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.awaitility.Awaitility.await;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.startsWith;

/**
 * Maintainer smoke test: the whole backend works against Floci. Not a model
 * answer for any topic; it only proves the app and the test support are healthy.
 */
@QuarkusTest
@WithTestResource(FlociTestResource.class)
class OrderFlowSmokeTest {

    @Test
    void shouldConfirmOrderAndStoreInvoiceWhenOrderIsCreated() {
        String productId = given()
                .contentType(ContentType.JSON)
                .body(Map.of("name", "Smoke product", "priceInCents", 2_500, "stock", 5))
                .post("/api/admin/products")
                .then().statusCode(201)
                .extract().path("id");

        String orderId = given()
                .contentType(ContentType.JSON)
                .body(Map.of("customerEmail", "smoke@example.com",
                        "items", java.util.List.of(Map.of("productId", productId, "quantity", 2))))
                .post("/api/orders")
                .then().statusCode(201)
                .body("status", equalTo("PENDING"))
                .body("totalInCents", equalTo(5_000))
                .extract().path("id");

        await().atMost(Duration.ofSeconds(15)).untilAsserted(() ->
                given().get("/api/orders/{id}", orderId)
                        .then().statusCode(200)
                        .body("status", equalTo("CONFIRMED"))
                        .body("invoiceKey", equalTo("invoices/" + orderId + ".pdf")));

        given().get("/api/orders/{id}/invoice", orderId)
                .then().statusCode(200)
                .body("url", startsWith("http"));

        given().get("/api/products/{id}", productId)
                .then().statusCode(200)
                .body("stock", equalTo(3));

        given().get("/api/orders/{id}/history", orderId)
                .then().statusCode(200)
                .body("status", org.hamcrest.Matchers.contains("PENDING", "CONFIRMED"));
    }
}
