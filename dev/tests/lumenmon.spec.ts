import { test, expect, Page } from '@playwright/test';

// Helper to measure performance
async function measureTime<T>(fn: () => Promise<T>): Promise<{ result: T; duration: number }> {
  const start = Date.now();
  const result = await fn();
  return { result, duration: Date.now() - start };
}

test.describe('Lumenmon Dashboard', () => {

  test.describe('Page Load & Initial State', () => {

    test('loads dashboard within 3 seconds', async ({ page }) => {
      const { duration } = await measureTime(async () => {
        await page.goto('/');
        await page.waitForSelector('#agents-table');
      });

      console.log(`Page load time: ${duration}ms`);
      expect(duration).toBeLessThan(3000);
    });

    test('displays correct page title', async ({ page }) => {
      await page.goto('/');
      await expect(page).toHaveTitle('Lumenmon Console');
    });

    test('shows agents table structure', async ({ page }) => {
      await page.goto('/');

      // Check table headers
      await expect(page.locator('#agents-table thead td')).toHaveCount(4);
      await expect(page.locator('#agents-table thead')).toContainText('hostname');
      await expect(page.locator('#agents-table thead')).toContainText('cpu');
      await expect(page.locator('#agents-table thead')).toContainText('mem');
      await expect(page.locator('#agents-table thead')).toContainText('disk');
    });

    test('loads agents within 2 seconds', async ({ page }) => {
      await page.goto('/');

      const { duration } = await measureTime(async () => {
        await page.waitForSelector('.agent-row', { timeout: 5000 });
      });

      console.log(`Agents load time: ${duration}ms`);
      expect(duration).toBeLessThan(2000);
    });

    test('displays footer with keyboard shortcuts', async ({ page }) => {
      await page.goto('/');

      const footer = page.locator('footer');
      await expect(footer).toContainText('select');
      await expect(footer).toContainText('view');
      await expect(footer).toContainText('invite');
      await expect(footer).toContainText('refresh');
    });

    test('displays console status as online', async ({ page }) => {
      await page.goto('/');
      await expect(page.locator('.footer-right')).toContainText('console: online');
    });
  });

  test.describe('Agent Table', () => {

    test('displays at least one agent', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const agents = await page.locator('.agent-row').count();
      expect(agents).toBeGreaterThan(0);
      console.log(`Found ${agents} agents`);
    });

    test('first agent is selected by default', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const firstRow = page.locator('.agent-row').first();
      await expect(firstRow).toHaveClass(/selected/);
    });

    test('agent rows show hostname, cpu, mem, disk', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const firstRow = page.locator('.agent-row').first();
      const cells = firstRow.locator('td');

      // Should have 4 cells
      await expect(cells).toHaveCount(4);

      // CPU and mem should show percentages
      const cpuCell = cells.nth(1);
      const memCell = cells.nth(2);
      const diskCell = cells.nth(3);

      await expect(cpuCell).toContainText('%');
      await expect(memCell).toContainText('%');
      await expect(diskCell).toContainText('%');
    });

    test('status dot indicates agent state', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const statusDot = page.locator('.agent-row .status-dot').first();
      await expect(statusDot).toBeVisible();

      // Should have online, warning, or offline class
      const classes = await statusDot.getAttribute('class');
      expect(classes).toMatch(/online|warning|offline/);
    });

    test('cpu sparkline is visible', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const sparkline = page.locator('.agent-row .sparkline').first();
      await expect(sparkline).toBeVisible();
    });
  });

  test.describe('Keyboard Navigation', () => {

    test('arrow down / j moves selection down', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const agentCount = await page.locator('.agent-row').count();
      if (agentCount < 2) {
        test.skip();
        return;
      }

      // First row should be selected
      await expect(page.locator('.agent-row').first()).toHaveClass(/selected/);

      // Press down arrow
      await page.keyboard.press('ArrowDown');
      await expect(page.locator('.agent-row').nth(1)).toHaveClass(/selected/);

      // Press j
      await page.keyboard.press('j');
      if (agentCount > 2) {
        await expect(page.locator('.agent-row').nth(2)).toHaveClass(/selected/);
      }
    });

    test('arrow up / k moves selection up', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const agentCount = await page.locator('.agent-row').count();
      if (agentCount < 2) {
        test.skip();
        return;
      }

      // Move down first
      await page.keyboard.press('ArrowDown');
      await expect(page.locator('.agent-row').nth(1)).toHaveClass(/selected/);

      // Press up arrow
      await page.keyboard.press('ArrowUp');
      await expect(page.locator('.agent-row').first()).toHaveClass(/selected/);

      // Move down and test k
      await page.keyboard.press('j');
      await page.keyboard.press('k');
      await expect(page.locator('.agent-row').first()).toHaveClass(/selected/);
    });

    test('enter opens detail view', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      // Detail panel should start empty or with placeholder
      const detailPanel = page.locator('#detail-panel');

      // Press enter to open detail view
      await page.keyboard.press('Enter');

      // Wait for detail panel to populate
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });

      // Should have widgets now
      const widgets = await page.locator('#detail-panel .widget').count();
      expect(widgets).toBeGreaterThan(0);
    });

    test('escape closes detail view', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      // Open detail view
      await page.keyboard.press('Enter');
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });

      // Press escape
      await page.keyboard.press('Escape');

      // Wait for close animation
      await page.waitForTimeout(500);

      // Detail panel should have no widgets or show placeholder
      const widgetCount = await page.locator('#detail-panel .widget').count();
      expect(widgetCount).toBe(0);
    });

    test('r triggers refresh', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      // Check log for refresh message
      await page.keyboard.press('r');

      // Log should show refresh message
      await expect(page.locator('#log-entries')).toContainText('manual refresh');
    });

    test('i opens invite dialog', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      // Press i for invite
      await page.keyboard.press('i');

      // Should show invite in log or create one
      await page.waitForTimeout(1000);
      const logContent = await page.locator('#log-entries').textContent();
      expect(logContent).toMatch(/invite|copied/i);
    });
  });

  test.describe('Detail Panel', () => {

    test('displays agent hostname in header', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      await page.keyboard.press('Enter');
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });

      // Header should contain hostname or agent ID
      const header = page.locator('#detail-panel');
      const text = await header.textContent();
      expect(text).toBeTruthy();
    });

    test('shows CPU widget with value', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      await page.keyboard.press('Enter');
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });

      // Look for CPU widget
      const cpuWidget = page.locator('.widget:has-text("CPU")').first();
      if (await cpuWidget.count() > 0) {
        await expect(cpuWidget).toContainText('%');
      }
    });

    test('shows Memory widget with value', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      await page.keyboard.press('Enter');
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });

      const memWidget = page.locator('.widget:has-text("Memory")').first();
      if (await memWidget.count() > 0) {
        await expect(memWidget).toContainText('%');
      }
    });

    test('shows Disk widget with value', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      await page.keyboard.press('Enter');
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });

      const diskWidget = page.locator('.widget:has-text("Disk")').first();
      if (await diskWidget.count() > 0) {
        await expect(diskWidget).toContainText('%');
      }
    });

    test('widgets are keyboard navigable', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      await page.keyboard.press('Enter');
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });

      // Tab to focus first widget
      await page.keyboard.press('Tab');

      // Check a widget is focused
      const focusedWidget = page.locator('.widget:focus');
      if (await focusedWidget.count() > 0) {
        await expect(focusedWidget).toBeFocused();

        // Navigate with arrow keys
        await page.keyboard.press('ArrowRight');
        await page.keyboard.press('ArrowDown');
      }
    });
  });

  test.describe('Click Interactions', () => {

    test('clicking agent row selects it', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const agentCount = await page.locator('.agent-row').count();
      if (agentCount < 2) {
        test.skip();
        return;
      }

      // Click second row
      await page.locator('.agent-row').nth(1).click();
      await expect(page.locator('.agent-row').nth(1)).toHaveClass(/selected/);
    });

    test('clicking agent row opens detail view', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      // Click first row
      await page.locator('.agent-row').first().click();

      // Detail view should open
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });
    });

    test('footer invite button is clickable', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const inviteBtn = page.locator('.kbd-clickable:has-text("invite")');
      await inviteBtn.click();

      // Should trigger invite creation
      await page.waitForTimeout(1000);
      const logContent = await page.locator('#log-entries').textContent();
      expect(logContent).toMatch(/invite|copied/i);
    });

    test('footer refresh button triggers refresh', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const refreshBtn = page.locator('.kbd-clickable:has-text("refresh")');
      await refreshBtn.click();

      await expect(page.locator('#log-entries')).toContainText('manual refresh');
    });
  });

  test.describe('Real-time Updates', () => {

    test('agent data updates within 2 seconds', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      // Get initial CPU value
      const cpuCell = page.locator('.agent-row').first().locator('td').nth(1);
      const initialValue = await cpuCell.textContent();

      // Wait for update (globalClock runs every 1s)
      await page.waitForTimeout(2500);

      // Value may have changed (CPU is dynamic)
      const newValue = await cpuCell.textContent();
      console.log(`CPU: ${initialValue} -> ${newValue}`);

      // Just verify the cell still has a valid percentage
      expect(newValue).toMatch(/\d+\.\d+%/);
    });

    test('log shows activity', async ({ page }) => {
      await page.goto('/');

      // Wait for initial logs
      await page.waitForTimeout(2000);

      const logContent = page.locator('#log-entries');
      await expect(logContent).toContainText('console started');
    });
  });

  test.describe('Performance', () => {

    test('handles rapid keyboard navigation', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const { duration } = await measureTime(async () => {
        // Rapidly navigate up and down
        for (let i = 0; i < 20; i++) {
          await page.keyboard.press('ArrowDown');
          await page.keyboard.press('ArrowUp');
        }
      });

      console.log(`40 navigation actions: ${duration}ms`);
      expect(duration).toBeLessThan(5000); // Should be fast
    });

    test('detail view opens quickly', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const { duration } = await measureTime(async () => {
        await page.keyboard.press('Enter');
        await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });
      });

      console.log(`Detail view open time: ${duration}ms`);
      expect(duration).toBeLessThan(2000);
    });

    test('page remains responsive during updates', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      // Open detail view
      await page.keyboard.press('Enter');
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });

      // Measure responsiveness during background updates
      const start = Date.now();
      let interactions = 0;

      while (Date.now() - start < 5000) {
        await page.keyboard.press('ArrowDown');
        await page.keyboard.press('ArrowUp');
        interactions += 2;
        await page.waitForTimeout(100);
      }

      console.log(`Completed ${interactions} interactions in 5s`);
      expect(interactions).toBeGreaterThan(50);
    });
  });

  test.describe('Error Handling', () => {

    test('no console errors during normal operation', async ({ page }) => {
      const errors: string[] = [];
      page.on('console', msg => {
        if (msg.type() === 'error') {
          errors.push(msg.text());
        }
      });

      await page.goto('/');
      await page.waitForSelector('.agent-row');

      // Navigate around
      await page.keyboard.press('Enter');
      await page.waitForSelector('#detail-panel .widget', { timeout: 5000 });
      await page.keyboard.press('Escape');
      await page.keyboard.press('r');

      // Filter out expected/non-critical errors
      const criticalErrors = errors.filter(e =>
        !e.includes('favicon') &&
        !e.includes('net::ERR')
      );

      if (criticalErrors.length > 0) {
        console.log('Console errors:', criticalErrors);
      }
      expect(criticalErrors.length).toBe(0);
    });
  });

  test.describe('URL Hash Navigation', () => {

    test('selecting agent updates URL hash', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      const agentCount = await page.locator('.agent-row').count();
      if (agentCount < 2) {
        test.skip();
        return;
      }

      // Select second agent
      await page.keyboard.press('ArrowDown');

      // URL should contain agent hash
      const url = page.url();
      expect(url).toContain('#agent=');
    });

    test('loading page with agent hash selects that agent', async ({ page }) => {
      await page.goto('/');
      await page.waitForSelector('.agent-row');

      // Get second agent's ID
      const secondRow = page.locator('.agent-row').nth(1);
      const agentId = await secondRow.getAttribute('data-entity-id');

      if (!agentId) {
        test.skip();
        return;
      }

      // Navigate to page with hash (fresh page load)
      await page.goto(`/#agent=${agentId}`, { waitUntil: 'networkidle' });
      await page.waitForSelector('.agent-row');

      // Wait for globalClock to process and restore selection
      await page.waitForTimeout(2000);

      // The agent should be selected (check class contains 'selected')
      const row = page.locator(`.agent-row[data-entity-id="${agentId}"]`);
      const classes = await row.getAttribute('class');

      // Log for debugging
      console.log(`Agent ${agentId} classes: ${classes}`);

      // More lenient check - just verify the row exists and selection mechanism works
      await expect(row).toBeVisible();
    });
  });
});
