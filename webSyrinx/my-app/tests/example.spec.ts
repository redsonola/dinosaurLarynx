import { test, defineConfig } from '@playwright/test';

defineConfig({ timeout: 60*24*60000 });
test.setTimeout(60*24*60000);

const WAIT_TO_LAUNCH = 5000;

test('has title', async ({ page }) => {
  await new Promise((ok) => { setTimeout(ok, WAIT_TO_LAUNCH) });
  
  await page.goto('https://localhost:5173');

  const play = await page.getByLabel('play a sound!');

  await play.click();

  // Expect a title "to contain" a substring.
  // await expect(page).toHaveTitle(/Playwright/);
  await new Promise(() => { });
});

// test('get started link', async ({ page }) => {
//   await page.goto('https://playwright.dev/');

//   // Click the get started link.
//   await page.getByRole('link', { name: 'Get started' }).click();

//   // Expects the URL to contain intro.
//   await expect(page).toHaveURL(/.*intro/);
// });
