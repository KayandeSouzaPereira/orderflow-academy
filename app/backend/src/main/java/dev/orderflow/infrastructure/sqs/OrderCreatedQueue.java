package dev.orderflow.infrastructure.sqs;

import dev.orderflow.infrastructure.config.OrderflowConfig;
import jakarta.enterprise.context.ApplicationScoped;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.GetQueueUrlRequest;

/** Resolves (once) the URL of the order-created queue. */
@ApplicationScoped
public class OrderCreatedQueue {

    private final SqsClient sqs;
    private final String queueName;
    private volatile String url;

    public OrderCreatedQueue(SqsClient sqs, OrderflowConfig config) {
        this.sqs = sqs;
        this.queueName = config.sqs().orderCreatedQueue();
    }

    public String url() {
        String current = url;
        if (current == null) {
            current = sqs.getQueueUrl(GetQueueUrlRequest.builder().queueName(queueName).build()).queueUrl();
            url = current;
        }
        return current;
    }
}
