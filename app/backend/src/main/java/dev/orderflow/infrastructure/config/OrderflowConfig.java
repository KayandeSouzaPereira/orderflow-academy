package dev.orderflow.infrastructure.config;

import io.smallrye.config.ConfigMapping;

import java.net.URI;
import java.time.Duration;

/** Typed view of the {@code orderflow.*} properties (see application.properties). */
@ConfigMapping(prefix = "orderflow")
public interface OrderflowConfig {

    Aws aws();

    Dynamodb dynamodb();

    Sqs sqs();

    S3 s3();

    Processor processor();

    Admin admin();

    interface Aws {
        URI endpoint();

        URI publicEndpoint();

        String region();

        String accessKeyId();

        String secretAccessKey();
    }

    interface Dynamodb {
        String productsTable();

        String ordersTable();

        String ordersByCustomerIndex();
    }

    interface Sqs {
        String orderCreatedQueue();
    }

    interface S3 {
        String bucket();

        Duration presignedUrlTtl();
    }

    interface Processor {
        boolean enabled();

        String pollInterval();

        long delayMs();

        int visibilityTimeoutSeconds();
    }

    interface Admin {
        boolean enabled();
    }
}
