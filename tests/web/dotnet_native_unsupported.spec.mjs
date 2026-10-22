import { expect, test } from '@playwright/test';

const pages = [["/dotnet/build", "Building .NET solutions requires", "Build", true], ["/dotnet/test", "Testing .NET projects requires", "Run tests and coverage", true], ["/dotnet/bump", "Windows and Linux", "Update version", false]];

for (const [route, explanation, action, disabledAction] of pages) {
  test(`GivenBrowser_WhenOpening${route}_ThenNativeRequirementIsAccessibleOffline`, async ({ page }) => {
    await page.goto(`/#${route}`);
    const placeholder = page.locator('flt-semantics-placeholder');
    await placeholder.waitFor({ state: 'attached' });
    await placeholder.evaluate(node => node.click());
    await page.context().setOffline(true);
    await expect(page.getByText(explanation, { exact: false })).toBeVisible();
    await expect(page.getByRole('textbox', { name: '', exact: true })).toHaveCount(0);
    const nativeAction = page.getByRole('button', { name: action, exact: true });
    if (disabledAction) {
      await expect(nativeAction).toBeVisible();
      await expect(nativeAction).toBeDisabled();
    } else {
      await expect(nativeAction).toHaveCount(0);
    }
  });
}
