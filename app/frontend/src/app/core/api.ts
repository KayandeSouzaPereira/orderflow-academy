import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiError, CreateOrderRequest, Order, PresignedUrl, Product } from './models';

/** Thin typed wrapper around the OrderFlow REST API. URLs are relative: /api is proxied. */
@Injectable({ providedIn: 'root' })
export class OrderFlowApi {
  private readonly http = inject(HttpClient);

  listProducts(): Observable<Product[]> {
    return this.http.get<Product[]>('/api/products');
  }

  productImage(productId: string): Observable<PresignedUrl> {
    return this.http.get<PresignedUrl>(`/api/products/${encodeURIComponent(productId)}/image`);
  }

  createOrder(request: CreateOrderRequest): Observable<Order> {
    return this.http.post<Order>('/api/orders', request);
  }

  getOrder(orderId: string): Observable<Order> {
    return this.http.get<Order>(`/api/orders/${encodeURIComponent(orderId)}`);
  }

  cancelOrder(orderId: string): Observable<Order> {
    return this.http.post<Order>(`/api/orders/${encodeURIComponent(orderId)}/cancel`, null);
  }

  invoice(orderId: string): Observable<PresignedUrl> {
    return this.http.get<PresignedUrl>(`/api/orders/${encodeURIComponent(orderId)}/invoice`);
  }
}

/** Extracts the API error body, if the failure carries one. */
export function apiErrorOf(error: unknown): ApiError | null {
  if (error instanceof HttpErrorResponse) {
    const body = error.error as Partial<ApiError> | null;
    if (body && typeof body.code === 'string' && typeof body.message === 'string') {
      return { code: body.code, message: body.message };
    }
  }
  return null;
}

/** HTTP status of a failed request, or 0 when the server could not be reached. */
export function statusOf(error: unknown): number {
  return error instanceof HttpErrorResponse ? error.status : 0;
}

/** True when a value looks like an order (protects the UI against malformed responses). */
export function isOrder(value: unknown): value is Order {
  const order = value as Partial<Order> | null;
  return (
    !!order &&
    typeof order.id === 'string' &&
    typeof order.status === 'string' &&
    typeof order.totalInCents === 'number' &&
    Array.isArray(order.items)
  );
}
