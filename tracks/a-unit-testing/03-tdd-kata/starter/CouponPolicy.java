package dev.orderflow.domain.coupon;

import jakarta.inject.Singleton;

import java.time.Clock;
import java.util.List;

/**
 * Applies discount coupons to an order total. Implement it test first,
 * following the rules in the topic README. Keep this public API unchanged.
 */
@Singleton
public class CouponPolicy {

    private final Clock clock;

    public CouponPolicy(Clock clock) {
        this.clock = clock;
    }

    /**
     * @param totalInCents order total, already including the 10% discount of large orders
     * @param coupons      coupons the customer typed (possibly none)
     * @return the total after the coupon, never negative
     * @throws CouponException when a coupon cannot be applied (see the README for the reasons)
     */
    public long apply(long totalInCents, List<Coupon> coupons) {
        throw new UnsupportedOperationException("Not implemented yet: start with a failing test.");
    }
}
