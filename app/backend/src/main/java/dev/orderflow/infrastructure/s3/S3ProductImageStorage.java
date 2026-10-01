package dev.orderflow.infrastructure.s3;

import dev.orderflow.application.port.PresignedUrl;
import dev.orderflow.application.port.ProductImageStorage;
import jakarta.enterprise.context.ApplicationScoped;

/** Product images live in the same bucket, under {@code images/}. */
@ApplicationScoped
public class S3ProductImageStorage implements ProductImageStorage {

    private final S3Presigning presigning;

    public S3ProductImageStorage(S3Presigning presigning) {
        this.presigning = presigning;
    }

    @Override
    public PresignedUrl presign(String key) {
        return presigning.presignGet(key);
    }
}
