import { expect, test } from '@playwright/test';
import { typeInto } from './helpers';

test.beforeEach(async ({ page }) => page.goto('/'));

test('sign-in validates and rejects unknown accounts', async ({ page }) => {
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await expect(page.getByText('Enter your email').first()).toBeVisible();
  await expect(page.getByText('Enter your password').first()).toBeVisible();

  await typeInto(page.getByRole('textbox', { name: 'Email' }), 'nobody@example.com');
  await typeInto(page.getByRole('textbox', { name: 'Password', exact: true }), 'wrong-password');
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await expect(page.getByText('That email and password do not match.').first()).toBeVisible();
  await expect(page).toHaveScreenshot('sign-in-error.png');
});

test('register validates phone and password, then signs in', async ({ page }) => {
  await page.getByRole('button', { name: 'Create account' }).click();
  const create = page.getByRole('button', { name: 'Create account' }).last();

  await typeInto(page.getByRole('textbox', { name: 'Email' }), 'field.officer@example.com');
  await typeInto(page.getByRole('textbox', { name: 'Mobile number' }), '12345');
  await typeInto(page.getByRole('textbox', { name: 'Password', exact: true }), 'short');
  await typeInto(page.getByRole('textbox', { name: 'Repeat password' }), 'other');
  await create.click();
  await expect(page.getByText('Enter a 10-digit Indian mobile number').first()).toBeVisible();
  await expect(page.getByText('Use at least 8 characters').first()).toBeVisible();
  await expect(page.getByText('The passwords do not match').first()).toBeVisible();

  await typeInto(page.getByRole('textbox', { name: 'Mobile number' }), '98765 43210');
  await typeInto(page.getByRole('textbox', { name: 'Password', exact: true }), 'mangrove-2026');
  await typeInto(page.getByRole('textbox', { name: 'Repeat password' }), 'mangrove-2026');
  await create.click();

  await expect(page.getByRole('heading', { name: 'IS IT PROTECTED?' })).toBeVisible({ timeout: 20_000 });
  await page.getByRole('tab', { name: 'Profile' }).click();
  await expect(page.getByText('field.officer@example.com').first()).toBeVisible();
  await expect(page.getByText('98765 43210').first()).toBeVisible();
});

test('OTP sign-in explains when the build has no API key', async ({ page }) => {
  await page.getByRole('button', { name: 'Sign in with a code by SMS' }).click();
  await typeInto(page.getByRole('textbox', { name: 'Mobile number' }), '98765 43210');
  await page.getByRole('button', { name: 'Send code' }).click();
  // No account with this number exists in a fresh browser.
  await expect(page.getByText('Phone number not registered').first()).toBeVisible();
});
