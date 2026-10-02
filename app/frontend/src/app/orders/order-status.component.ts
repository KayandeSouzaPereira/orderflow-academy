import { Component, DestroyRef, InjectionToken, effect, inject, input, signal, untracked } from '@angular/core';
import { Subscription, switchMap, takeWhile, timer } from 'rxjs';
import { OrderFlowApi, apiErrorOf, isOrder, statusOf } from '../core/api';
import { Order } from '../core/models';
import { MoneyPipe } from '../core/money.pipe';

/** How often a PENDING order is refreshed. Tests can provide a smaller value. */
export const ORDER_POLL_INTERVAL_MS = new InjectionToken<number>('ORDER_POLL_INTERVAL_MS', {
  factory: () => 2000,
});

/**
 * Shows one order and keeps it up to date: while the order is PENDING it is
 * fetched again every {@link ORDER_POLL_INTERVAL_MS}; polling stops once the
 * order is CONFIRMED or CANCELLED.
 */
@Component({
  selector: 'app-order-status',
  imports: [MoneyPipe],
  templateUrl: './order-status.component.html',
  styleUrl: './order-status.component.css',
})
export class OrderStatusComponent {
  private readonly api = inject(OrderFlowApi);
  private readonly pollIntervalMs = inject(ORDER_POLL_INTERVAL_MS);
  private readonly destroyRef = inject(DestroyRef);

  /** Order id, bound from the route parameter. */
  readonly id = input.required<string>();

  protected readonly order = signal<Order | null>(null);
  protected readonly notFound = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly cancelling = signal(false);
  protected readonly actionError = signal<string | null>(null);
  protected readonly invoiceUrl = signal<string | null>(null);
  protected readonly justCreated = signal(false);

  private polling: Subscription | null = null;

  constructor() {
    const state = (history.state ?? {}) as { justCreated?: boolean };
    this.justCreated.set(state.justCreated === true);

    // (Re)load whenever the id changes, e.g. when tracking another order.
    effect(() => {
      this.id();
      untracked(() => {
        this.reset();
        this.startPolling();
      });
    });
    this.destroyRef.onDestroy(() => this.stopPolling());
  }

  protected cancel(): void {
    const current = this.order();
    if (!current || this.cancelling()) {
      return;
    }
    this.cancelling.set(true);
    this.actionError.set(null);
    this.api.cancelOrder(current.id).subscribe({
      next: (order) => {
        this.cancelling.set(false);
        if (isOrder(order)) {
          this.stopPolling();
          this.order.set(order);
        }
      },
      error: (err: unknown) => {
        this.cancelling.set(false);
        this.actionError.set(
          statusOf(err) === 409
            ? (apiErrorOf(err)?.message ?? 'This order can no longer be cancelled.')
            : 'The order could not be cancelled. Please try again.',
        );
        // The status probably changed meanwhile: show the current one.
        this.startPolling();
      },
    });
  }

  private startPolling(): void {
    this.stopPolling();
    this.polling = timer(0, this.pollIntervalMs)
      .pipe(
        switchMap(() => this.api.getOrder(this.id())),
        takeWhile((order) => isOrder(order) && order.status === 'PENDING', true),
      )
      .subscribe({
        next: (order) => this.show(order),
        error: (err: unknown) => {
          if (statusOf(err) === 404) {
            this.notFound.set(true);
          } else {
            this.loadError.set('Could not load the order. Please try again later.');
          }
        },
      });
  }

  private reset(): void {
    this.order.set(null);
    this.notFound.set(false);
    this.loadError.set(null);
    this.actionError.set(null);
    this.invoiceUrl.set(null);
  }

  private stopPolling(): void {
    this.polling?.unsubscribe();
    this.polling = null;
  }

  private show(order: Order): void {
    if (!isOrder(order)) {
      this.loadError.set('The server sent an unexpected response.');
      return;
    }
    this.loadError.set(null);
    this.order.set(order);
    if (order.status === 'CONFIRMED' && !this.invoiceUrl()) {
      this.api.invoice(order.id).subscribe({
        next: (invoice) => this.invoiceUrl.set(invoice.url),
        error: () => this.invoiceUrl.set(null),
      });
    }
  }
}
