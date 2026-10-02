import { Component, OnInit, inject, signal } from '@angular/core';
import { OrderFlowApi } from '../core/api';
import { Product } from '../core/models';
import { MoneyPipe } from '../core/money.pipe';
import { CartService } from '../cart/cart.service';

@Component({
  selector: 'app-catalog-page',
  imports: [MoneyPipe],
  templateUrl: './catalog-page.html',
  styleUrl: './catalog-page.css',
})
export class CatalogPage implements OnInit {
  private readonly api = inject(OrderFlowApi);
  private readonly cart = inject(CartService);

  protected readonly products = signal<Product[]>([]);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);
  /** Pre-signed image URL per product id; missing while it loads or when it fails. */
  protected readonly imageUrls = signal<Record<string, string>>({});
  protected readonly brokenImages = signal<Record<string, boolean>>({});
  protected readonly lastAdded = signal<string | null>(null);

  ngOnInit(): void {
    this.api.listProducts().subscribe({
      next: (products) => {
        const list = Array.isArray(products) ? products : [];
        this.products.set(list);
        this.loading.set(false);
        list.forEach((product) => this.loadImage(product.id));
      },
      error: () => {
        this.loading.set(false);
        this.error.set('Could not load the catalog. Please try again later.');
      },
    });
  }

  protected addToCart(product: Product): void {
    this.cart.add(product);
    this.lastAdded.set(`${product.name} added to the cart.`);
  }

  protected markBroken(productId: string): void {
    this.brokenImages.update((broken) => ({ ...broken, [productId]: true }));
  }

  private loadImage(productId: string): void {
    this.api.productImage(productId).subscribe({
      next: (image) => this.imageUrls.update((urls) => ({ ...urls, [productId]: image.url })),
      error: () => this.markBroken(productId),
    });
  }
}
