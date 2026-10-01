package dev.orderflow.api.dto;

import dev.orderflow.domain.OrderHistory;
import dev.orderflow.domain.OrderStatus;

import java.time.Instant;

public record HistoryEntryResponse(OrderStatus status, Instant at) {

    public static HistoryEntryResponse from(OrderHistory.Entry entry) {
        return new HistoryEntryResponse(entry.status(), entry.at());
    }
}
