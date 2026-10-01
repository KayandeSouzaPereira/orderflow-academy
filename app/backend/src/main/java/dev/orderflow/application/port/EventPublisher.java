package dev.orderflow.application.port;

import dev.orderflow.domain.OrderCreated;

public interface EventPublisher {

    void publish(OrderCreated event);
}
