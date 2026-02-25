import { test, expect, Page } from '@playwright/test';

async function openDashboard(page: Page) {
  await page.goto('/');
  await expect(page.getByText('console: online')).toBeVisible();
}

test.describe('Lumenmon legacy-style dashboard', () => {
  test('loads shell with logger and list', async ({ page }) => {
    await openDashboard(page);
    await expect(page.locator('.logo-ascii')).toBeVisible();
    await expect(page.getByRole('heading', { name: 'hostname' })).toBeVisible();
  });

  test('renders detail panel and widgets', async ({ page }) => {
    await openDashboard(page);
    await page.waitForSelector('tbody tr.agent-row');
    await expect(page.locator('#detail-panel')).toBeVisible();
    await expect(page.getByText('All Values')).toBeVisible();
  });

  test('keyboard row navigation works', async ({ page }) => {
    await openDashboard(page);
    await page.waitForSelector('tbody tr.agent-row');
    const first = page.locator('tbody tr.agent-row').first();
    await expect(first).toHaveClass(/selected/);
    await page.keyboard.press('j');
    await page.keyboard.press('k');
    await expect(first).toHaveClass(/selected/);
  });

  test('refresh shortcut logs event', async ({ page }) => {
    await openDashboard(page);
    await page.keyboard.press('r');
    await expect(page.getByText('manual refresh')).toBeVisible();
  });

  test('mobile still loads list and detail placeholder', async ({ browser }) => {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    await openDashboard(page);
    await expect(page.getByRole('heading', { name: 'hostname' })).toBeVisible();
    await expect(page.locator('#detail-panel')).toBeVisible();
    await context.close();
  });
});
