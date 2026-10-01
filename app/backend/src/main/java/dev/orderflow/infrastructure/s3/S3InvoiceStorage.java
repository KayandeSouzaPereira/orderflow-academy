package dev.orderflow.infrastructure.s3;

import dev.orderflow.application.port.InvoiceStorage;
import dev.orderflow.application.port.PresignedUrl;
import dev.orderflow.infrastructure.config.OrderflowConfig;
import jakarta.enterprise.context.ApplicationScoped;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

/** Stores invoices as {@code application/pdf} objects in the bucket. */
@ApplicationScoped
public class S3InvoiceStorage implements InvoiceStorage {

    static final String PDF_CONTENT_TYPE = "application/pdf";

    private final S3Client s3;
    private final S3Presigning presigning;
    private final String bucket;

    public S3InvoiceStorage(S3Client s3, S3Presigning presigning, OrderflowConfig config) {
        this.s3 = s3;
        this.presigning = presigning;
        this.bucket = config.s3().bucket();
    }

    @Override
    public void store(String key, byte[] pdf) {
        s3.putObject(PutObjectRequest.builder()
                        .bucket(bucket)
                        .key(key)
                        .contentType(PDF_CONTENT_TYPE)
                        .build(),
                RequestBody.fromBytes(pdf));
    }

    @Override
    public PresignedUrl presign(String key) {
        return presigning.presignGet(key);
    }
}
