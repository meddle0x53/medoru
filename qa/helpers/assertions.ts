/**
 * Custom assertions and expectations for Medoru QA testing
 */

import { Page, Locator, expect } from '@playwright/test';

/**
 * Assert that the page shows a specific heading
 */
export async function expectHeading(page: Page, text: string | RegExp): Promise<void> {
  const heading = page.locator('h1, h2').filter({ hasText: text }).first();
  await expect(heading).toBeVisible();
}

/**
 * Assert that a toast/flash message is displayed
 */
export async function expectFlashMessage(
  page: Page,
  text: string | RegExp,
  type: 'info' | 'error' | 'success' = 'info'
): Promise<void> {
  const flashSelector = `[data-testid="flash-${type}"], .flash-${type}, .alert-${type}`;
  const flash = page.locator(flashSelector).filter({ hasText: text });
  await expect(flash).toBeVisible();
}

/**
 * Assert that user is logged in
 */
export async function expectAuthenticated(page: Page, userName?: string): Promise<void> {
  // Check for user menu or avatar
  const userIndicator = page.locator(
    '[data-testid="user-menu"], [data-testid="user-avatar"], header:has-text("Dashboard")'
  );
  await expect(userIndicator).toBeVisible();

  // If user name provided, verify it's shown somewhere
  if (userName) {
    const userNameElement = page.locator(`text=${userName}`).first();
    await expect(userNameElement).toBeVisible();
  }
}

/**
 * Assert that user is logged out
 */
export async function expectUnauthenticated(page: Page): Promise<void> {
  // Check for login button/link
  const loginButton = page.locator(
    'a:has-text("Sign in"), a:has-text("Login"), a:has-text("Log in"), button:has-text("Sign in")'
  );

  // Either login button is visible, or dashboard link is not visible
  const dashboardLink = page.locator('nav a[href="/dashboard"], a:has-text("Dashboard")');

  const isLoginVisible = await loginButton.isVisible().catch(() => false);
  const isDashboardVisible = await dashboardLink.isVisible().catch(() => false);

  expect(isLoginVisible || !isDashboardVisible).toBeTruthy();
}

/**
 * Assert that page has specific text somewhere
 */
export async function expectPageText(page: Page, text: string | RegExp): Promise<void> {
  const element = page.locator('body').filter({ hasText: text });
  await expect(element).toBeVisible();
}

/**
 * Assert that an element has specific test id and is visible
 */
export async function expectTestIdVisible(page: Page, testId: string): Promise<void> {
  const element = page.locator(`[data-testid="${testId}"]`);
  await expect(element).toBeVisible();
}

/**
 * Assert that current URL matches pattern
 */
export async function expectUrl(page: Page, pattern: string | RegExp): Promise<void> {
  const url = page.url();
  if (typeof pattern === 'string') {
    expect(url).toContain(pattern);
  } else {
    expect(url).toMatch(pattern);
  }
}

/**
 * Assert that a button is disabled
 */
export async function expectDisabled(locator: Locator): Promise<void> {
  await expect(locator).toBeDisabled();
}

/**
 * Assert that a button is enabled
 */
export async function expectEnabled(locator: Locator): Promise<void> {
  await expect(locator).toBeEnabled();
}

/**
 * Assert that an input has specific value
 */
export async function expectInputValue(locator: Locator, value: string): Promise<void> {
  await expect(locator).toHaveValue(value);
}

/**
 * Assert that page has no console errors
 */
export async function expectNoConsoleErrors(page: Page): Promise<void> {
  const errors: string[] = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });

  // Give some time for any errors to appear
  await page.waitForTimeout(1000);

  expect(errors).toHaveLength(0);
}

/**
 * Assert that a form validation error is shown
 */
export async function expectValidationError(
  page: Page,
  fieldName: string,
  errorText?: string
): Promise<void> {
  const errorSelector = errorText
    ? `[data-testid="error-${fieldName}"]:has-text("${errorText}"), .error-${fieldName}:has-text("${errorText}")`
    : `[data-testid="error-${fieldName}"], .error-${fieldName}`;

  const errorElement = page.locator(errorSelector);
  await expect(errorElement).toBeVisible();
}

/**
 * Assert that a loading state is shown
 */
export async function expectLoadingState(page: Page, testId?: string): Promise<void> {
  const selector = testId
    ? `[data-testid="${testId}"]`
    : '[data-testid="loading"], .loading, [aria-busy="true"]';
  const loader = page.locator(selector).first();
  await expect(loader).toBeVisible();
}

/**
 * Wait for loading to complete
 */
export async function waitForLoadingComplete(page: Page, timeout = 10000): Promise<void> {
  const loader = page.locator('[data-testid="loading"], .loading, [aria-busy="true"]').first();

  try {
    await loader.waitFor({ state: 'visible', timeout: 2000 });
    await loader.waitFor({ state: 'hidden', timeout });
  } catch {
    // Loading might already be complete
  }
}

/**
 * Assert that page is accessible (basic checks)
 */
export async function expectAccessible(page: Page): Promise<void> {
  // Check for proper heading structure
  const h1 = page.locator('h1');
  const h1Count = await h1.count();
  expect(h1Count).toBeGreaterThan(0);

  // Check for lang attribute
  const html = page.locator('html');
  await expect(html).toHaveAttribute('lang', /.+/);

  // Check for proper landmark regions
  const main = page.locator('main, [role="main"]');
  await expect(main).toBeVisible();
}
