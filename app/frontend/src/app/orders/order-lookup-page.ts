import { Component, inject } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';

@Component({
  selector: 'app-order-lookup-page',
  imports: [ReactiveFormsModule],
  template: `
    <h1>Track an order</h1>
    <form class="lookup" [formGroup]="form" (ngSubmit)="track()" novalidate>
      <label for="order-id">Order ID</label>
      <input id="order-id" type="text" autocomplete="off" formControlName="orderId" />
      <button type="submit" [disabled]="orderId.invalid">Track</button>
    </form>
  `,
  styles: `
    .lookup {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 0.5rem;
    }
    .lookup input {
      min-width: 22rem;
      max-width: 100%;
    }
  `,
})
export class OrderLookupPage {
  private readonly router = inject(Router);

  protected readonly orderId = new FormControl('', {
    nonNullable: true,
    validators: [Validators.required, Validators.pattern(/\S/)],
  });
  protected readonly form = new FormGroup({ orderId: this.orderId });

  protected track(): void {
    const id = this.orderId.value.trim();
    if (id) {
      void this.router.navigate(['/orders', id]);
    }
  }
}
