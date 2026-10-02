package dev.orderflow.domain.coupon;

import java.time.LocalDate;

/**
 * A discount coupon. Do not change this file: the review uses it as is.
 *
 * @param code                code typed by the customer, e.g. "WELCOME10"
 * @param type                PERCENTAGE (value is 1..100) or FIXED (value in cents)
 * @param value               percentage or amount in cents, depending on the type
 * @param minimumOrderInCents smallest order total the coupon accepts
 * @param validFrom           first day the coupon can be used (inclusive)
 * @param validUntil          last day the coupon can be used (inclusive)
 */
public record Coupon(String code, Type type, long value, long minimumOrderInCents,
                     LocalDate validFrom, LocalDate validUntil) {

    public enum Type {
        PERCENTAGE,
        FIXED
    }
}
