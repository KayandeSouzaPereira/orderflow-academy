package dev.orderflow.application.port;

import java.time.Instant;

public record PresignedUrl(String url, Instant expiresAt) {
}
