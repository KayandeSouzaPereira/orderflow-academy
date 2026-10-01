import { randomUUID } from 'node:crypto';

/**
 * Where the OrderFlow API answers (default http://localhost:8080). Use it as
 * the base URL of Playwright's `request` fixture to prepare test data:
 *
 *   await request.post(`${apiBaseURL}/api/admin/products`, { data: { ... } });
 */
export const apiBaseURL = process.env['API_BASE_URL'] ?? 'http://localhost:8080';

/** A short unique suffix, so every test (and every run) has its own data. */
export function uniqueId(prefix = 'e2e'): string {
  return `${prefix}-${randomUUID().slice(0, 8)}`;
}

/** A unique, valid e-mail address. */
export function uniqueEmail(): string {
  return `${uniqueId('customer')}@example.com`;
}
