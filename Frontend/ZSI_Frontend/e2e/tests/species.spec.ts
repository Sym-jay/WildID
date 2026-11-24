import { expect, test } from '@playwright/test';
import { openAsGuest, typeInto } from './helpers';

test.beforeEach(async ({ page }) => {
  await openAsGuest(page);
  await page.getByRole('tab', { name: 'Species' }).click();
  await expect(page.getByRole('heading', { name: 'Protected species' })).toBeVisible();
});

test('filters by schedule', async ({ page }) => {
  await expect(page.getByRole('checkbox', { name: 'All 65' })).toBeVisible();
  await page.getByRole('checkbox', { name: 'Schedule I · 18' }).click();
  await expect(page.getByText('Bowmouth Guitarfish').first()).toBeVisible();
  await expect(page.getByText('Blue Shark')).toHaveCount(0);
  await expect(page).toHaveScreenshot('species-schedule-1.png');
});

test('search finds by common or scientific name', async ({ page }) => {
  const search = page.getByRole('textbox', { name: /Search by common or scientific name/ });
  await typeInto(search, 'whale');
  await expect(page.getByText('Whale Shark').first()).toBeVisible();
  await typeInto(search, 'prionace');
  await expect(page.getByText('Blue Shark').first()).toBeVisible();
  await typeInto(search, 'zzzz');
  await expect(page.getByText('No species match "zzzz"').first()).toBeVisible();
});

test('species detail shows protection and IUCN link', async ({ page }) => {
  await typeInto(page.getByRole('textbox', { name: /Search by common or scientific name/ }), 'whale');
  await page.getByText('Whale Shark').click();
  await expect(page.getByText('PROTECTED').first()).toBeVisible();
  await expect(page.getByText(/Schedule I\. Catching, keeping/).first()).toBeVisible();
  await expect(page.getByRole('button', { name: 'See it on the IUCN Red List' })).toBeVisible();
});
