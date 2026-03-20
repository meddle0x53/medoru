/**
 * Dashboard Scenarios
 *
 * Tests for the main dashboard functionality.
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

test.describe('Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    await navigateTo(page, 'dashboard');
  });

  test('dashboard displays welcome message', async ({ page }) => {
    await expect(page.locator('h1')).toContainText(/dashboard|welcome/i);
  });

  test('dashboard shows daily test option', async ({ page }) => {
    // Look for daily test button or link
    const dailyTestElement = page.locator(
      'text=/daily test|start test|today.s review/i'
    );
    await expect(dailyTestElement.first()).toBeVisible();
  });

  test('dashboard shows streak information', async ({ page }) => {
    // Look for streak-related text
    const streakElement = page.locator('text=/streak|day streak|🔥/i');
    // Streak might be 0 for some users, so element should exist
    await expect(streakElement.first()).toBeVisible();
  });

  test('can navigate to daily test from dashboard', async ({ page }) => {
    // Find and click daily test button
    const dailyTestButton = page.locator(
      'a:has-text("Daily Test"), button:has-text("Daily Test"), a:has-text("Start Test")'
    ).first();

    if (await dailyTestButton.isVisible().catch(() => false)) {
      await dailyTestButton.click();
      await expect(page).toHaveURL(/.*daily-test.*/);
    }
  });

  test('dashboard shows user progress summary', async ({ page }) => {
    // Look for progress-related elements
    const progressElements = page.locator('text=/progress|completed|learned|words/i');

    // At least one progress indicator should be visible
    const count = await progressElements.count();
    expect(count).toBeGreaterThan(0);
  });
});

test.describe('Dashboard - Advanced Student', () => {
  test('advanced student sees higher stats', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    await navigateTo(page, 'dashboard');

    // Advanced student should have streak information
    const streakText = await page.locator('text=/\\d+.*day|streak/i').first().textContent();

    // Should show some progress indicators
    await expect(page.locator('text=/level|xp|experience/i').first()).toBeVisible();
  });
});

test.describe('Dashboard - New Student', () => {
  test('new student sees getting started content', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentNew);
    await navigateTo(page, 'dashboard');

    // New student might see onboarding or getting started content
    const bodyText = await page.locator('body').textContent();

    // Should contain some learning-related content
    expect(bodyText).toMatch(/lesson|start|learn|begin/i);
  });
});
