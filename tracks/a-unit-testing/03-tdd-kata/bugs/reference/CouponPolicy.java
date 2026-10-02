package dev.orderflow.domain.coupon;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

/**
 * Reference implementation used by the review: bugs are planted in this file.
 * Participants agreed not to open the bugs/ folder.
 */
public class CouponPolicy {

    private final Clock clock;

    public CouponPolicy(Clock clock) {
        this.clock = clock;
    }

    public long apply(long totalInCents, List<Coupon> coupons) {
        if (coupons.isEmpty()) {
            return totalInCents;
        }
        if (coupons.size() > 1) {
            throw new CouponException(CouponException.Reason.NOT_CUMULATIVE, "Only one coupon per order.");
        }
        Coupon coupon = coupons.get(0);

        LocalDate today = LocalDate.now(clock);
        if (today.isBefore(coupon.validFrom())) {
            throw new CouponException(CouponException.Reason.NOT_YET_VALID, coupon.code() + " is not valid yet.");
        }
        if (today.isAfter(coupon.validUntil())) {
            throw new CouponException(CouponException.Reason.EXPIRED, coupon.code() + " has expired.");
        }
        if (totalInCents < coupon.minimumOrderInCents()) {
            throw new CouponException(CouponException.Reason.MINIMUM_NOT_REACHED,
                    coupon.code() + " needs an order of at least " + coupon.minimumOrderInCents() + " cents.");
        }
        return switch (coupon.type()) {
            case PERCENTAGE -> applyPercentage(totalInCents, coupon);
            case FIXED -> applyFixed(totalInCents, coupon);
        };
    }

    private static long applyPercentage(long totalInCents, Coupon coupon) {
        if (coupon.value() < 1 || coupon.value() > 100) {
            throw new CouponException(CouponException.Reason.INVALID_COUPON, "Percentage must be 1..100.");
        }
        return totalInCents - totalInCents * coupon.value() / 100;
    }

    private static long applyFixed(long totalInCents, Coupon coupon) {
        if (coupon.value() <= 0) {
            throw new CouponException(CouponException.Reason.INVALID_COUPON, "Fixed amount must be positive.");
        }
        return Math.max(0, totalInCents - coupon.value());
    }
}
