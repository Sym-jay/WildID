import { expect, test } from '@playwright/test';
import { backToHome, identifyPhoto, openAsGuest } from './helpers';

test('history lists, filters, opens and deletes a report', async ({ page }) => {
  await openAsGuest(page);
  await identifyPhoto(page);
  await backToHome(page);

  // The report also shows on Home.
  await expect(page.getByRole('button', { name: /^Reef Manta Ray/ })).toBeVisible();

  await page.getByRole('tab', { name: 'History' }).click();
  await expect(page.getByRole('heading', { name: 'Your reports' })).toBeVisible();
  await expect(page.getByRole('checkbox', { name: 'All 1' })).toBeVisible();

  await page.getByRole('checkbox', { name: 'Verified' }).click();
  await expect(page.getByText('No reports match this filter.').first()).toBeVisible();
  await page.getByRole('checkbox', { name: 'Protected' }).click();
  await page.getByRole('button', { name: /^Reef Manta Ray/ }).first().click();

  // Detail sheet
  await expect(page.getByText('91% match').first()).toBeVisible();
  await expect(page.getByText('Not reviewed yet').first()).toBeVisible();
  await page.getByRole('button', { name: 'Delete report' }).click();
  await expect(page.getByText('Delete this report?').first()).toBeVisible();
  await page.getByRole('button', { name: 'Delete', exact: true }).click();

  await expect(page.getByText('Report deleted').first()).toBeVisible();
  await page.getByRole('checkbox', { name: /^All/ }).click();
  await expect(page.getByText('No reports yet').first()).toBeVisible();
});

test('expert review verifies a report', async ({ page }) => {
  await openAsGuest(page);
  await identifyPhoto(page);
  await backToHome(page);

  await page.getByRole('tab', { name: 'Profile' }).click();
  await page.getByRole('button', { name: /Expert review queue/ }).click();
  await page.getByRole('button', { name: /^Reef Manta Ray/ }).first().click();
  await page.getByRole('button', { name: 'Confirm species' }).dispatchEvent('click');
  await expect(page.getByText('Verified as Reef Manta Ray').first()).toBeVisible();
  await expect(page.getByText('Nothing to review').first()).toBeVisible();
});
