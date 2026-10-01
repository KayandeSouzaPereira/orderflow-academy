package dev.orderflow.domain.coupon;

/** A coupon cannot be applied. Do not change this file: the review uses it as is. */
public class CouponException extends RuntimeException {

    public enum Reason {
        NOT_CUMULATIVE,
        NOT_YET_VALID,
        EXPIRED,
        MINIMUM_NOT_REACHED,
        INVALID_COUPON
    }

    private final Reason reason;

    public CouponException(Reason reason, String message) {
        super(message);
        this.reason = reason;
    }

    public Reason reason() {
        return reason;
    }
}
