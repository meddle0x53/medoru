/**
 * Authentication helpers for QA testing
 *
 * Provides utilities for logging in as test users via the QA bypass API.
 */

import { Page, APIRequestContext } from '@playwright/test';
import { TestUser } from '../fixtures/users';

export interface AuthHelper {
  /**
   * Login as a specific test user via API
   */
  login: (user: TestUser) => Promise<void>;

  /**
   * Login as a specific test user via UI
   */
  loginViaUI: (user: TestUser) => Promise<void>;

  /**
   * Logout the current user
   */
  logout: () => Promise<void>;

  /**
   * Check if user is authenticated
   */
  isAuthenticated: () => Promise<boolean>;
}

/**
 * Create an authentication helper for a Playwright page
 */
export function createAuthHelper(page: Page): AuthHelper {
  return {
    /**
     * Login as a specific test user via API (fastest method)
     */
    async login(user: TestUser): Promise<void> {
      // Use the QA bypass API to login
      const response = await page.request.post('/qa/bypass/api/login', {
        data: { email: user.email },
      });

      if (!response.ok()) {
        const error = await response.text();
        throw new Error(`Failed to login as ${user.email}: ${error}`);
      }

      // Navigate to home page to ensure session is established
      await page.goto('/');
      await page.waitForLoadState('networkidle');
      
      // Wait for LiveView to mount
      await page.waitForTimeout(1000);

      // Wait for user menu or avatar to appear (indicating logged in state)
      await page.waitForSelector('header, nav, .navbar, [data-testid="user-menu"], [data-testid="user-avatar"]', {
        state: 'visible',
        timeout: 10000,
      }).catch(() => {
        // If no specific test id, just wait for page load
        return page.waitForLoadState('networkidle');
      });
    },

    /**
     * Login as a specific test user via UI (slower but tests the UI flow)
     */
    async loginViaUI(user: TestUser): Promise<void> {
      // Go to the QA bypass page
      await page.goto('/qa/bypass');

      // Wait for the page to load
      await page.waitForSelector('text=QA Login Bypass', { timeout: 10000 });

      // Find and click the button for this user
      const userButton = page.locator(`button:has-text("${user.email}")`);
      await userButton.click();

      // Wait for redirect to home page
      await page.waitForURL('/', { timeout: 10000 });
    },

    /**
     * Logout the current user
     */
    async logout(): Promise<void> {
      // Navigate to logout
      await page.goto('/auth/logout');

      // Wait for redirect (usually to home or login page)
      await page.waitForLoadState('networkidle');
    },

    /**
     * Check if a user is currently authenticated
     */
    async isAuthenticated(): Promise<boolean> {
      try {
        // Check for logged-in indicators
        const userMenu = page.locator('[data-testid="user-menu"], [data-testid="user-avatar"], header nav:has-text("Dashboard")');
        return await userMenu.isVisible({ timeout: 3000 });
      } catch {
        return false;
      }
    },
  };
}

/**
 * Pre-authenticate and save storage state for a user
 * Used in setup tests to create authenticated sessions
 */
export async function authenticateAndSaveState(
  request: APIRequestContext,
  user: TestUser,
  storageStatePath: string
): Promise<void> {
  // Create a new browser context with the request
  const response = await request.post('/qa/bypass/api/login', {
    data: { email: user.email },
  });

  if (!response.ok()) {
    throw new Error(`Failed to authenticate ${user.email}`);
  }

  // Get cookies from response
  const cookies = await request.storageState();

  // Save to file
  const fs = await import('fs/promises');
  await fs.mkdir(storageStatePath.split('/').slice(0, -1).join('/'), { recursive: true });
  await fs.writeFile(storageStatePath, JSON.stringify(cookies, null, 2));
}

/**
 * Wait for the QA server to be ready
 */
export async function waitForServer(request: APIRequestContext, maxRetries = 30): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const response = await request.get('/qa/health', { timeout: 5000 });
      if (response.ok()) {
        const data = await response.json();
        if (data.status === 'ok') {
          console.log('✅ QA server is ready');
          return;
        }
      }
    } catch {
      // Server not ready yet
    }

    console.log(`⏳ Waiting for QA server... (${i + 1}/${maxRetries})`);
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }

  throw new Error('QA server did not become ready in time');
}
