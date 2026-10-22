import { expect, test } from '@playwright/test';

test('GivenBrowser_WhenScaffoldingDotnetProject_ThenNativeRequirementIsExplainedOffline', async ({ page }) => {
  await page.goto('/#/dotnet/init-project');
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached' });
  await placeholder.evaluate(node => node.click());
  await page.context().setOffline(true);
  await page.getByRole('textbox', { name: 'Project name', exact: true }).fill('Example');
  await page.getByRole('button', { name: 'Create .NET project', exact: true }).click();
  await expect(page.getByText('Project creation is available in the Windows and Linux desktop and CLI applications.', { exact: true })).toBeVisible();
});
