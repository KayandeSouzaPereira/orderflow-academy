import { Component, inject, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { finalize } from 'rxjs';
import { OrderFlowApi, apiErrorOf, isOrder, statusOf } from '../core/api';
import { MoneyPipe } from '../core/money.pipe';
import { CartService, MAX_QUANTITY, MIN_QUANTITY } from './cart.service';

@Component({
  selector: 'app-cart-page',
  imports: [MoneyPipe, ReactiveFormsModule, RouterLink],
  templateUrl: './cart-page.html',
  styleUrl: './cart-page.css',
})
export class CartPage {
  private readonly api = inject(OrderFlowApi);
  private readonly router = inject(Router);
  protected readonly cart = inject(CartService);

  protected readonly minQuantity = MIN_QUANTITY;
  protected readonly maxQuantity = MAX_QUANTITY;

  protected readonly email = new FormControl('', {
    nonNullable: true,
    validators: [Validators.required, Validators.email],
  });
  protected readonly checkoutForm = new FormGroup({ email: this.email });
  protected readonly submitting = signal(false);
  protected readonly error = signal<string | null>(null);

  protected updateQuantity(productId: string, event: Event): void {
    const value = Number((event.target as HTMLInputElement).value);
    this.cart.setQuantity(productId, value);
  }

  protected canSubmit(): boolean {
    return !this.submitting() && !this.cart.isEmpty() && this.email.valid;
  }

  protected placeOrder(): void {
    this.email.markAsTouched();
    if (!this.canSubmit()) {
      return;
    }
    this.submitting.set(true);
    this.error.set(null);

    const request = {
      customerEmail: this.email.value.trim(),
      items: this.cart.items().map((line) => ({ productId: line.product.id, quantity: line.quantity })),
    };

    this.api
      .createOrder(request)
      .pipe(finalize(() => this.submitting.set(false)))
      .subscribe({
        next: (order) => {
          if (!isOrder(order)) {
            this.error.set('The server sent an unexpected response. Please try again.');
            return;
          }
          this.cart.clear();
          this.email.reset();
          void this.router.navigate(['/orders', order.id], { state: { justCreated: true } });
        },
        error: (err: unknown) => this.error.set(describeOrderError(err)),
      });
  }
}

/** Turns a failed order creation into a message for the customer. */
export function describeOrderError(error: unknown): string {
  const apiError = apiErrorOf(error);
  switch (statusOf(error)) {
    case 409:
      return apiError?.message ?? 'Some products are out of stock.';
    case 400:
    case 404:
      return apiError?.message ?? 'The order could not be created. Please review the cart.';
    case 0:
      return 'Could not reach the server. Check your connection and try again.';
    default:
      return 'Something went wrong while creating the order. Please try again.';
  }
}
