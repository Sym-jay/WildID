import { expect, type Locator, type Page } from '@playwright/test';
import path from 'node:path';

export const photo = path.join(__dirname, '..', 'fixtures', 'photo.jpg');

/** Open the app and continue as a guest; lands on the Identify tab. */
export async function openAsGuest(page: Page) {
  await page.goto('/');
  await page.getByRole('button', { name: 'Continue as guest' }).click();
  await expect(page.getByRole('heading', { name: 'IS IT PROTECTED?' })).toBeVisible();
}

/** Take a photo (the web picker opens a file chooser) and wait for the result. */
export async function identifyPhoto(page: Page) {
  const chooser = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Take photo' }).click();
  await (await chooser).setFiles(photo);
  await expect(page.getByText(/^SCHEDULE I\. PROTECTED\. DO NOT KEEP\./).first()).toBeVisible();
}

/** Leave the result screen. */
export async function backToHome(page: Page) {
  await page.getByRole('button', { name: 'Back' }).first().click();
  await expect(page.getByRole('heading', { name: 'IS IT PROTECTED?' })).toBeVisible();
}

/**
 * Replace a Flutter text field's value. Playwright's fill() can race with
 * Flutter's text editing on web, so type the way a person would.
 */
export async function typeInto(field: Locator, text: string) {
  await field.click();
  await field.press('ControlOrMeta+a');
  await field.press('Backspace');
  await field.pressSequentially(text, { delay: 10 });
  await expect(field).toHaveValue(text);
}
