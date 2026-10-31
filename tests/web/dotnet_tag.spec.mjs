import { expect, test } from '@playwright/test';

test('GivenBrowser_WhenCreatingReleaseTag_ThenUnsupportedTargetIsExplainedOffline', async ({ page }) => {
  await page.goto('/#/dotnet/tag');
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached' });
  await placeholder.evaluate(node => node.click());
  await page.context().setOffline(true);
  await page.getByRole('button', { name: 'Create annotated tag', exact: true }).click();
  await expect(page.getByRole('group', { name: 'Release tags are available in the Windows and Linux desktop and CLI applications.', exact: true })).toBeVisible();
});
