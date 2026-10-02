import { expect, test } from '@playwright/test';

// Maintainer smoke test: the UI is up and shows the catalog. Not a model answer.
test('shows the catalog with the seed products', async ({ page }) => {
  await page.goto('/');

  await expect(page).toHaveTitle('Catalog | OrderFlow');
  await expect(page.getByRole('heading', { name: 'Catalog' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'USB-C Hub' })).toBeVisible();
});
