import { Injectable, computed, effect, signal } from '@angular/core';
import { Product } from '../core/models';

export const MIN_QUANTITY = 1;
export const MAX_QUANTITY = 10;

export interface CartLine {
  product: Product;
  quantity: number;
}

export const CART_STORAGE_KEY = 'orderflow.cart';

/**
 * Shopping cart. One line per product; quantities are clamped to 1..10, the
 * same range the API accepts. The cart survives page reloads (localStorage).
 */
@Injectable({ providedIn: 'root' })
export class CartService {
  private readonly lines = signal<CartLine[]>(loadLines());

  readonly items = this.lines.asReadonly();

  /** Number of units in the cart (shown in the header). */
  readonly count = computed(() => this.lines().reduce((sum, line) => sum + line.quantity, 0));

  /** Sum of quantity x unit price, before any discount the API may apply. */
  readonly subtotalInCents = computed(() =>
    this.lines().reduce((sum, line) => sum + line.quantity * line.product.priceInCents, 0),
  );

  readonly isEmpty = computed(() => this.lines().length === 0);

  constructor() {
    effect(() => saveLines(this.lines()));
  }

  /** Adds one unit of the product, or a new line if it is not in the cart yet. */
  add(product: Product): void {
    const existing = this.lines().find((line) => line.product.id === product.id);
    if (existing) {
      this.setQuantity(product.id, existing.quantity + 1);
    } else {
      this.lines.update((lines) => [...lines, { product, quantity: MIN_QUANTITY }]);
    }
  }

  setQuantity(productId: string, quantity: number): void {
    const clamped = Math.min(MAX_QUANTITY, Math.max(MIN_QUANTITY, Math.trunc(quantity) || MIN_QUANTITY));
    this.lines.update((lines) =>
      lines.map((line) => (line.product.id === productId ? { ...line, quantity: clamped } : line)),
    );
  }

  /** Removes the line of one product; other lines stay untouched. */
  remove(productId: string): void {
    this.lines.update((lines) => lines.filter((line) => line.product.id !== productId));
  }

  clear(): void {
    this.lines.set([]);
  }
}

function loadLines(): CartLine[] {
  try {
    const parsed: unknown = JSON.parse(localStorage.getItem(CART_STORAGE_KEY) ?? '[]');
    return Array.isArray(parsed)
      ? parsed.filter((line: Partial<CartLine>) => !!line?.product?.id && typeof line.quantity === 'number')
      : [];
  } catch {
    return [];
  }
}

function saveLines(lines: CartLine[]): void {
  try {
    localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(lines));
  } catch {
    // Storage unavailable (private mode, quota): the cart just won't survive a reload.
  }
}
