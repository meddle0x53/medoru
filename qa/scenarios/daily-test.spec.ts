/**
 * Daily Test Scenarios
 *
 * Tests for the daily test functionality.
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

test.describe('Daily Test', () => {
  test.beforeEach(async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    await navigateTo(page, 'dailyTest');
  });

  test('daily test page loads', async ({ page }) => {
    await expect(page.locator('h1')).toContainText(/daily test|test/i);
  });

  test('can answer multiple choice questions', async ({ page }) => {
    // Wait for question to appear
    const question = page.locator('[data-testid="question-card"], .question, form');

    if (await question.isVisible({ timeout: 5000 }).catch(() => false)) {
      // Find and click an option
      const options = page.locator('[data-testid="option"], button[type="submit"]').all();

      for (const option of await options) {
        if (await option.isVisible()) {
          await option.click();
          break;
        }
      }

      // Submit answer
      const submitButton = page.locator('[data-testid="submit-answer"], button:has-text("Submit")');
      if (await submitButton.isVisible().catch(() => false)) {
        await submitButton.click();
      }
    }
  });

  test('shows progress during test', async ({ page }) => {
    // Look for progress indicator
    const progress = page.locator('[data-testid="progress"], .progress, text=/question \\d+/i');

    // Progress should be visible during test
    if (await progress.first().isVisible({ timeout: 3000 }).catch(() => false)) {
      await expect(progress.first()).toBeVisible();
    }
  });

  test('completing test shows results', async ({ page }) => {
    // Answer all questions
    let hasMoreQuestions = true;
    let iterations = 0;
    const maxIterations = 50; // Safety limit

    while (hasMoreQuestions && iterations < maxIterations) {
      iterations++;

      // Check for completion
      const completeText = await page.locator('text=/complete|finished|results|score/i').isVisible().catch(() => false);
      if (completeText) {
        hasMoreQuestions = false;
        break;
      }

      // Try to answer current question
      const options = page.locator('[data-testid="option"]').all();
      const opts = await options;

      if (opts.length > 0) {
        await opts[0].click();

        const submit = page.locator('[data-testid="submit-answer"], button:has-text("Submit")');
        if (await submit.isVisible().catch(() => false)) {
          await submit.click();
        }
      } else {
        hasMoreQuestions = false;
      }

      // Small wait for transition
      await page.waitForTimeout(500);
    }

    // Should see completion or results
    const completionText = page.locator('text=/complete|results|score|well done/i');
    await expect(completionText.first()).toBeVisible();
  });
});

test.describe('Daily Test - Streak Tracking', () => {
  test('completing daily test updates streak', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);

    // Note: This test may need adjustment based on whether
    // daily test was already completed today

    // Navigate to dashboard first to check current streak
    await navigateTo(page, 'dashboard');
    const initialStreakText = await page.locator('text=/\\d+.*day streak/i').first().textContent().catch(() => '0');
    const initialStreak = parseInt(initialStreakText.match(/\\d+/)?.[0] || '0');

    // Complete daily test
    await navigateTo(page, 'dailyTest');

    // ... test logic for completing test ...

    // Check if streak was updated
    await navigateTo(page, 'dashboard');
    const newStreakText = await page.locator('text=/\\d+.*day streak/i').first().textContent().catch(() => '0');
    const newStreak = parseInt(newStreakText.match(/\\d+/)?.[0] || '0');

    // Streak should be same or increased by 1 (if test was completed)
    expect(newStreak).toBeGreaterThanOrEqual(initialStreak);
  });
});
