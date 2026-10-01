package dev.orderflow.infrastructure.sqs;

import dev.orderflow.application.port.EventPublisher;
import dev.orderflow.domain.OrderCreated;
import jakarta.enterprise.context.ApplicationScoped;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

/** Publishes {@link OrderCreated} to the order-created queue as JSON. */
@ApplicationScoped
public class SqsEventPublisher implements EventPublisher {

    private final SqsClient sqs;
    private final OrderCreatedQueue queue;

    public SqsEventPublisher(SqsClient sqs, OrderCreatedQueue queue) {
        this.sqs = sqs;
        this.queue = queue;
    }

    @Override
    public void publish(OrderCreated event) {
        sqs.sendMessage(SendMessageRequest.builder()
                .queueUrl(queue.url())
                .messageBody(OrderCreatedMessage.toJson(event))
                .build());
    }
}
