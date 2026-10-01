package dev.orderflow.application.port;

public interface InvoiceStorage {

    /** Stores a PDF invoice under {@code key}. */
    void store(String key, byte[] pdf);

    /** Returns a temporary download URL for the invoice stored under {@code key}. */
    PresignedUrl presign(String key);
}
