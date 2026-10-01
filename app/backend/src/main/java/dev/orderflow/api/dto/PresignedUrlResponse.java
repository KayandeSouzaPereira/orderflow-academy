package dev.orderflow.api.dto;

import dev.orderflow.application.port.PresignedUrl;

import java.time.Instant;

public record PresignedUrlResponse(String url, Instant expiresAt) {

    public static PresignedUrlResponse from(PresignedUrl presigned) {
        return new PresignedUrlResponse(presigned.url(), presigned.expiresAt());
    }
}
