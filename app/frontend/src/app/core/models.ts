/** Shapes of the OrderFlow REST API. Money is always an integer in cents. */

export interface Product {
  id: string;
  name: string;
  description: string | null;
  priceInCents: number;
  stock: number;
}

export type OrderStatus = 'PENDING' | 'CONFIRMED' | 'CANCELLED';

export interface OrderItem {
  productId: string;
  quantity: number;
  unitPriceInCents: number;
}

export interface Order {
  id: string;
  customerEmail: string;
  items: OrderItem[];
  totalInCents: number;
  status: OrderStatus;
  invoiceKey: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateOrderRequest {
  customerEmail: string;
  items: { productId: string; quantity: number }[];
}

export interface PresignedUrl {
  url: string;
  expiresAt: string;
}

/** Error body returned by every failing endpoint. */
export interface ApiError {
  code: string;
  message: string;
}
