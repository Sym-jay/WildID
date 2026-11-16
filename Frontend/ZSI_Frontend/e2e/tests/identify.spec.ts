import { expect, test } from '@playwright/test';
import { backToHome, identifyPhoto, openAsGuest, typeInto } from './helpers';

test.describe('Identify', () => {
  test.beforeEach(async ({ page }) => openAsGuest(page));

  test('home shows the status key and an empty report list', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Take photo' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Choose from gallery' })).toBeVisible();
    await expect(page.getByText('No reports yet').first()).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Identify' })).toHaveAttribute('aria-selected', 'true');
    await expect(page).toHaveScreenshot('home.png');
  });

  test('a photo gives a Schedule I verdict with alternatives', async ({ page }) => {
    await identifyPhoto(page);
    await expect(page.getByText('Demo result: this build does not contact the server.').first()).toBeVisible();
    await expect(page.getByRole('button', { name: /^Reef Manta Ray\. 91 percent match/ })).toBeVisible();
    // A scientific-name label must resolve to its common name.
    await expect(page.getByText('Giant Devil Ray').first()).toBeVisible();
    await expect(page.getByText(/Saved to your reports/).first()).toBeVisible();
    // Back stays reachable for screen-reader users.
    await expect(page.getByRole('button', { name: 'Back' })).toBeVisible();
    await expect(page).toHaveScreenshot('result.png');
  });

  test('report details update the same report', async ({ page }) => {
    await identifyPhoto(page);
    await page.getByRole('button', { name: 'Add details for ZSI' }).click();
    await expect(page.getByRole('heading', { name: 'Report details' })).toBeVisible();
    await page.getByRole('checkbox', { name: 'Fish landing centre' }).click();
    await page.getByRole('button', { name: 'Alive' }).click();
    await typeInto(page.getByRole('textbox', { name: 'Water depth in metres (if known)' }), '-3');
    await page.getByRole('button', { name: 'Save details' }).click();
    await expect(page.getByText('Enter a depth in metres, like 12').first()).toBeVisible();
    await typeInto(page.getByRole('textbox', { name: 'Water depth in metres (if known)' }), '12');
    await page.getByRole('button', { name: 'Save details' }).click();
    await expect(page.getByRole('button', { name: 'Edit report details' })).toBeVisible();

    await backToHome(page);
    // One identification = one report, even after adding details.
    await page.getByRole('tab', { name: 'History' }).click();
    await expect(page.getByRole('checkbox', { name: 'All 1' })).toBeVisible();
    await expect(page.getByText(/Fish landing centre/).first()).toBeVisible();
  });
});
