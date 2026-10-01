import { Pipe, PipeTransform } from '@angular/core';

const FORMAT = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'BRL' });

/** Formats an integer amount in cents: 45990 -> "R$459.90". */
export function formatCents(cents: number): string {
  return FORMAT.format(cents / 100);
}

@Pipe({ name: 'money' })
export class MoneyPipe implements PipeTransform {
  transform(cents: number | null | undefined): string {
    return cents == null ? '' : formatCents(cents);
  }
}
