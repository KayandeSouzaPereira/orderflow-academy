package dev.orderflow.infrastructure.processor;

import dev.orderflow.application.ProcessOrderCreatedUseCase;
import dev.orderflow.domain.OrderCreated;
import dev.orderflow.infrastructure.config.OrderflowConfig;
import dev.orderflow.infrastructure.sqs.OrderCreatedMessage;
import dev.orderflow.infrastructure.sqs.OrderCreatedQueue;
import io.quarkus.scheduler.Scheduled;
import io.quarkus.scheduler.Scheduled.ConcurrentExecution;
import io.quarkus.scheduler.ScheduledExecution;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Singleton;
import org.jboss.logging.Logger;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

/**
 * Polls the order-created queue and hands each event to
 * {@link ProcessOrderCreatedUseCase}.
 *
 * <p>Events younger than {@code orderflow.processor.delay-ms} are left in the
 * queue and picked up again once their visibility timeout expires. This keeps
 * orders observable as PENDING without blocking the poller.
 */
@ApplicationScoped
public class OrderCreatedPoller {

    private static final Logger LOG = Logger.getLogger(OrderCreatedPoller.class);

    private final SqsClient sqs;
    private final OrderCreatedQueue queue;
    private final ProcessOrderCreatedUseCase useCase;
    private final OrderflowConfig.Processor config;
    private final Clock clock;
    private String lastPollError;

    public OrderCreatedPoller(SqsClient sqs, OrderCreatedQueue queue, ProcessOrderCreatedUseCase useCase,
                              OrderflowConfig config, Clock clock) {
        this.sqs = sqs;
        this.queue = queue;
        this.useCase = useCase;
        this.config = config.processor();
        this.clock = clock;
    }

    @Scheduled(identity = "order-created-poller",
            every = "${orderflow.processor.poll-interval}",
            concurrentExecution = ConcurrentExecution.SKIP,
            skipExecutionIf = ProcessorDisabled.class)
    void poll() {
        List<Message> messages;
        try {
            messages = sqs.receiveMessage(ReceiveMessageRequest.builder()
                    .queueUrl(queue.url())
                    .maxNumberOfMessages(10)
                    .waitTimeSeconds(0)
                    .visibilityTimeout(config.visibilityTimeoutSeconds())
                    .build()).messages();
            clearPollError();
        } catch (RuntimeException e) {
            reportPollError(e);
            return;
        }
        for (Message message : messages) {
            handle(message);
        }
    }

    private void handle(Message message) {
        OrderCreated event;
        try {
            event = OrderCreatedMessage.fromJson(message.body());
        } catch (IllegalArgumentException e) {
            LOG.errorf("Dropping malformed message %s: %s", message.messageId(), e.getMessage());
            delete(message);
            return;
        }

        if (!isDue(event)) {
            return; // Becomes visible again after the visibility timeout.
        }

        try {
            ProcessOrderCreatedUseCase.Outcome outcome = useCase.execute(event);
            LOG.infof("Order %s processed: %s", event.orderId(), outcome);
            delete(message);
        } catch (RuntimeException e) {
            LOG.errorf(e, "Failed to process order %s; it will be retried", event.orderId());
        }
    }

    private boolean isDue(OrderCreated event) {
        Instant dueAt = event.occurredAt().plusMillis(config.delayMs());
        return !clock.instant().isBefore(dueAt);
    }

    private void delete(Message message) {
        sqs.deleteMessage(DeleteMessageRequest.builder()
                .queueUrl(queue.url())
                .receiptHandle(message.receiptHandle())
                .build());
    }

    /** Logs a polling failure once, instead of once per second, until it changes. */
    private void reportPollError(RuntimeException e) {
        String summary = e.getClass().getSimpleName() + ": " + e.getMessage();
        if (!Objects.equals(summary, lastPollError)) {
            LOG.warnf("Cannot poll the order-created queue (is Floci running and initialised?) - %s", summary);
            lastPollError = summary;
        }
    }

    private void clearPollError() {
        if (lastPollError != null) {
            LOG.info("Polling the order-created queue again");
            lastPollError = null;
        }
    }

    /** Skips polling when {@code orderflow.processor.enabled=false}. */
    @Singleton
    public static class ProcessorDisabled implements Scheduled.SkipPredicate {

        private final OrderflowConfig config;

        public ProcessorDisabled(OrderflowConfig config) {
            this.config = config;
        }

        @Override
        public boolean test(ScheduledExecution execution) {
            return !config.processor().enabled();
        }
    }
}
