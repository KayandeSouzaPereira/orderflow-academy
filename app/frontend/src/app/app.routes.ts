import { Routes } from '@angular/router';
import { CartPage } from './cart/cart-page';
import { CatalogPage } from './catalog/catalog-page';
import { OrderLookupPage } from './orders/order-lookup-page';
import { OrderStatusComponent } from './orders/order-status.component';

export const routes: Routes = [
  { path: '', component: CatalogPage, title: 'Catalog | OrderFlow' },
  { path: 'cart', component: CartPage, title: 'Cart | OrderFlow' },
  { path: 'orders', component: OrderLookupPage, title: 'Track order | OrderFlow' },
  { path: 'orders/:id', component: OrderStatusComponent, title: 'Order | OrderFlow' },
  { path: '**', redirectTo: '' },
];
