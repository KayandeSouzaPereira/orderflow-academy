package dev.orderflow.application.port;

public interface ProductImageStorage {

    /** Returns a temporary URL for the image stored under {@code key}. */
    PresignedUrl presign(String key);
}
