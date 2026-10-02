package dev.orderflow.infrastructure.s3;

import dev.orderflow.application.port.PresignedUrl;
import dev.orderflow.infrastructure.config.OrderflowConfig;
import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;

import java.time.Duration;

/**
 * Builds pre-signed GET URLs for objects in the bucket. Uses
 * {@code orderflow.aws.public-endpoint}, because the URL is opened by a browser
 * or a test that may not see the same host name as the backend.
 */
@ApplicationScoped
public class S3Presigning {

    private final S3Presigner presigner;
    private final String bucket;
    private final Duration ttl;

    public S3Presigning(OrderflowConfig config) {
        OrderflowConfig.Aws aws = config.aws();
        this.presigner = S3Presigner.builder()
                .endpointOverride(aws.publicEndpoint())
                .region(Region.of(aws.region()))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(aws.accessKeyId(), aws.secretAccessKey())))
                .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build())
                .build();
        this.bucket = config.s3().bucket();
        this.ttl = config.s3().presignedUrlTtl();
    }

    public PresignedUrl presignGet(String key) {
        PresignedGetObjectRequest request = presigner.presignGetObject(GetObjectPresignRequest.builder()
                .signatureDuration(ttl)
                .getObjectRequest(GetObjectRequest.builder().bucket(bucket).key(key).build())
                .build());
        return new PresignedUrl(request.url().toString(), request.expiration());
    }

    @PreDestroy
    void close() {
        presigner.close();
    }
}
