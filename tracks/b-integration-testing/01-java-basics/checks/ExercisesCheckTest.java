package dev.orderflow.exercises;

import dev.orderflow.exercises.Model.Order;
import dev.orderflow.exercises.Model.OrderLine;
import dev.orderflow.exercises.Model.Product;
import dev.orderflow.exercises.Model.Status;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Maintainer checks for topic B-01. The review copies this class into the
 * exercises module and scores the share of checks that pass.
 */
class ExercisesCheckTest {

    private static final Product KEYBOARD = new Product("p-1", "Keyboard", 45_990, 3);
    private static final Product MOUSE = new Product("p-2", "Mouse", 12_990, 0);
    private static final Product CABLE = new Product("p-3", "Cable", 990, 10);
    private static final Product LAMP = new Product("p-4", "Lamp", 7_990, 1);

    private static Order order(String id, String email, Status status, OrderLine... lines) {
        return new Order(id, email, status, List.of(lines));
    }

    private static OrderLine line(String productId, int quantity, long price) {
        return new OrderLine(productId, quantity, price);
    }

    // 1
    @Test
    void ex01SumsQuantityTimesPrice() {
        Order order = order("o-1", "a@b.com", Status.PENDING, line("p-1", 2, 1_000), line("p-2", 3, 250));
        assertThat(Exercises.totalInCents(order)).isEqualTo(2_750);
    }

    @Test
    void ex01ReturnsZeroForNoLines() {
        assertThat(Exercises.totalInCents(order("o-1", "a@b.com", Status.PENDING))).isZero();
    }

    // 2
    @Test
    void ex02KeepsOnlyProductsInStockSortedByName() {
        assertThat(Exercises.namesInStock(List.of(KEYBOARD, MOUSE, CABLE, LAMP)))
                .containsExactly("Cable", "Keyboard", "Lamp");
    }

    @Test
    void ex02ReturnsEmptyListWhenNothingIsInStock() {
        assertThat(Exercises.namesInStock(List.of(MOUSE))).isEmpty();
    }

    // 3
    @Test
    void ex03CountsOrdersPerStatus() {
        List<Order> orders = List.of(
                order("o-1", "a@b.com", Status.PENDING),
                order("o-2", "a@b.com", Status.CONFIRMED),
                order("o-3", "c@d.com", Status.CONFIRMED));
        assertThat(Exercises.countByStatus(orders))
                .containsExactlyInAnyOrderEntriesOf(Map.of(Status.PENDING, 1L, Status.CONFIRMED, 2L));
    }

    @Test
    void ex03ReturnsEmptyMapForNoOrders() {
        assertThat(Exercises.countByStatus(List.of())).isEmpty();
    }

    // 4
    @Test
    void ex04FindsTheCheapestProduct() {
        assertThat(Exercises.cheapest(List.of(KEYBOARD, CABLE, LAMP))).contains(CABLE);
    }

    @Test
    void ex04ReturnsEmptyForNoProducts() {
        assertThat(Exercises.cheapest(List.of())).isEmpty();
    }

    // 5
    @Test
    void ex05FormatsCentsWithTwoDecimals() {
        assertThat(Exercises.formatCents(123_456)).isEqualTo("BRL 1234.56");
        assertThat(Exercises.formatCents(5)).isEqualTo("BRL 0.05");
    }

    @Test
    void ex05FormatsZero() {
        assertThat(Exercises.formatCents(0)).isEqualTo("BRL 0.00");
    }

    // 6
    @Test
    void ex06ParsesValidQuantities() {
        assertThat(Exercises.parseQuantity("1")).isEqualTo(1);
        assertThat(Exercises.parseQuantity(" 10 ")).isEqualTo(10);
    }

    @Test
    void ex06RejectsTextAndOutOfRangeValues() {
        assertThatThrownBy(() -> Exercises.parseQuantity("abc"))
                .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("abc");
        assertThatThrownBy(() -> Exercises.parseQuantity("11"))
                .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("11");
        assertThatThrownBy(() -> Exercises.parseQuantity("0")).isInstanceOf(IllegalArgumentException.class);
    }

    // 7
    @Test
    void ex07AcceptsValidEmails() {
        assertThat(Exercises.isValidEmail("ana@example.com")).isTrue();
        assertThat(Exercises.isValidEmail("ana.silva+orders@shop.com.br")).isTrue();
    }

    @Test
    void ex07RejectsInvalidEmails() {
        assertThat(Exercises.isValidEmail(null)).isFalse();
        assertThat(Exercises.isValidEmail("ana.example.com")).isFalse();
        assertThat(Exercises.isValidEmail("@example.com")).isFalse();
        assertThat(Exercises.isValidEmail("ana@example")).isFalse();
        assertThat(Exercises.isValidEmail("ana@@example.com")).isFalse();
    }

    // 8
    @Test
    void ex08FiltersOrdersByEmailIgnoringCase() {
        Order first = order("o-1", "Ana@Example.com", Status.PENDING);
        Order other = order("o-2", "bob@example.com", Status.PENDING);
        Order second = order("o-3", "ana@example.com", Status.CONFIRMED);
        assertThat(Exercises.ordersOf(List.of(first, other, second), "ANA@example.com"))
                .containsExactly(first, second);
    }

    // 9
    @Test
    void ex09SumsUnitsOfConfirmedOrdersOnly() {
        List<Order> orders = List.of(
                order("o-1", "a@b.com", Status.CONFIRMED, line("p-1", 2, 100), line("p-2", 1, 100)),
                order("o-2", "a@b.com", Status.CONFIRMED, line("p-1", 3, 100)),
                order("o-3", "a@b.com", Status.CANCELLED, line("p-1", 50, 100)));
        assertThat(Exercises.unitsSoldByProduct(orders)).containsExactlyInAnyOrderEntriesOf(Map.of("p-1", 5, "p-2", 1));
    }

    // 10
    @Test
    void ex10FindsTheCustomerWhoSpentMost() {
        List<Order> orders = List.of(
                order("o-1", "ana@b.com", Status.CONFIRMED, line("p-1", 1, 1_000)),
                order("o-2", "bob@b.com", Status.CONFIRMED, line("p-1", 1, 700)),
                order("o-3", "bob@b.com", Status.CONFIRMED, line("p-1", 1, 700)),
                order("o-4", "ana@b.com", Status.PENDING, line("p-1", 1, 9_000)));
        assertThat(Exercises.bestCustomer(orders)).contains("bob@b.com");
    }

    @Test
    void ex10ReturnsEmptyWithoutConfirmedOrders() {
        assertThat(Exercises.bestCustomer(List.of(order("o-1", "a@b.com", Status.PENDING, line("p", 1, 1))))).isEmpty();
    }

    // 11
    @Test
    void ex11SplitsIntoPages() {
        assertThat(Exercises.pages(List.of(KEYBOARD, MOUSE, CABLE, LAMP, KEYBOARD), 2))
                .containsExactly(List.of(KEYBOARD, MOUSE), List.of(CABLE, LAMP), List.of(KEYBOARD));
    }

    @Test
    void ex11RejectsPageSizeBelowOne() {
        assertThatThrownBy(() -> Exercises.pages(List.of(KEYBOARD), 0)).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void ex11ReturnsNoPagesForNoProducts() {
        assertThat(Exercises.pages(new ArrayList<>(), 3)).isEmpty();
    }

    // 12
    @Test
    void ex12CancelsPendingOrderWithoutChangingTheOriginal() {
        Order pending = order("o-1", "a@b.com", Status.PENDING, line("p-1", 1, 100));
        Order cancelled = Exercises.cancel(pending);
        assertThat(cancelled.status()).isEqualTo(Status.CANCELLED);
        assertThat(cancelled.id()).isEqualTo("o-1");
        assertThat(cancelled.lines()).isEqualTo(pending.lines());
        assertThat(pending.status()).isEqualTo(Status.PENDING);
    }

    @Test
    void ex12RefusesToCancelConfirmedOrders() {
        assertThatThrownBy(() -> Exercises.cancel(order("o-1", "a@b.com", Status.CONFIRMED)))
                .isInstanceOf(IllegalStateException.class);
    }
}
