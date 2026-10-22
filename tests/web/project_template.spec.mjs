import { expect, test } from '@playwright/test';

test('GivenBrowser_WhenCreatingProject_ThenNativeRequirementIsExplainedOffline', async ({ page }) => {
  await page.goto('/#/project/from-template');
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached' });
  await placeholder.evaluate(node => node.click());
  await page.context().setOffline(true);
  await page.getByRole('textbox', { name: 'New destination path', exact: true }).fill('new-project');
  await page.locator('[aria-live="polite"]').evaluate(node => {
    window.projectTemplateAnnouncements = [];
    new MutationObserver(() => {
      window.projectTemplateAnnouncements.push(node.textContent);
    }).observe(node, { childList: true, characterData: true, subtree: true });
  });
  await page.getByRole('button', { name: 'Create project', exact: true }).click();
  const explanation = 'Project creation is available in the Windows and Linux desktop and CLI applications.';
  await expect(page.getByRole('group', { name: explanation, exact: true })).toBeVisible();
  await expect.poll(() => page.evaluate(() => window.projectTemplateAnnouncements)).toContain(explanation);
});
