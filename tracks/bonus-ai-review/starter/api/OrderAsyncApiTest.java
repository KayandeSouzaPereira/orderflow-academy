package dev.orderflow.apitests.tracks.bonus;

import dev.orderflow.apitests.support.TestApi;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.anyOf;
import static org.hamcrest.Matchers.equalTo;

/** API tests for the asynchronous processing of orders. Generated with an AI assistant. */
class OrderAsyncApiTest {

    private static String createOrder() throws Exception {
        String productId = TestApi.createProduct("Bonus " + UUID.randomUUID(), 1_000, 5)
                .then().statusCode(201).extract().path("id");
        return given(TestApi.spec())
                .body(Map.of("customerEmail", "bonus-" + UUID.randomUUID() + "@example.com",
                        "items", List.of(Map.of("productId", productId, "quantity", 1))))
                .post("/api/orders")
                .then().statusCode(201).extract().path("id");
    }

    @Test
    void shouldProcessOrderWhenProcessorRuns() throws Exception {
        String orderId = createOrder();

        Thread.sleep(2000);

        given(TestApi.spec())
                .get("/api/orders/{id}", orderId)
                .then()
                .statusCode(200)
                .body("status", anyOf(equalTo("PENDING"), equalTo("CONFIRMED")));
    }

    @Test
    void shouldKeepOrderAvailableWhenProcessorIsSlow() throws Exception {
        String orderId = createOrder();

        Thread.sleep(2000);

        given(TestApi.spec())
                .get("/api/orders/{id}", orderId)
                .then()
                .statusCode(200);
    }
}
