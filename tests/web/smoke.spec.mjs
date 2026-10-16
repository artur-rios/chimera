import { expect, test } from '@playwright/test';

test('compiled Chimera shell loads without page errors', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));

  const response = await page.goto('/');

  expect(response?.ok()).toBe(true);
  await expect(page).toHaveTitle('Chimera');
  expect(pageErrors).toEqual([]);
});

