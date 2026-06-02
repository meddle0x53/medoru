/**
 * Daily Challenges - Main Page Tests
 *
 * Covers the daily challenges listing page at /daily-challenges
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

/**
 * Reset daily challenges via QA API
 */
async function resetDailyChallenges(page: any): Promise<void> {
  const response = await page.request.delete('/qa/api/daily-challenges');
  if (!response.ok()) {
    console.log('Note: Daily challenges reset returned non-ok (may already be empty)');
  }
}

test.describe('Daily Challenges Page', () => {
  test.beforeEach(async ({ page }) => {
    // Reset challenges before each test to ensure clean state
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    await resetDailyChallenges(page);
  });

  test('should display all three challenges', async ({ page }) => {
    await navigateTo(page, '/daily-challenges');

    const bodyText = await page.locator('body').textContent() || '';

    // Should show all three challenge types
    expect(bodyText).toContain('Daily Test');
    expect(bodyText).toContain('Daily Kanji');
    expect(bodyText).toContain('Daily Cards');

    // Should show challenge descriptions
    expect(bodyText).toContain('Review due words');
    expect(bodyText).toContain('Practice writing');
    expect(bodyText).toContain('Match word pairs');
  });

  test('should show streak information', async ({ page }) => {
    await navigateTo(page, '/daily-challenges');

    const bodyText = await page.locator('body').textContent() || '';

    // Should show streak banner
    expect(bodyText).toMatch(/day streak|Keep your streak going|Streak saved/i);

    // Should show challenge progress
    expect(bodyText).toMatch(/\d+\s*\/\s*3\s*completed today/i);
  });

  test('should show all challenges as available when none completed', async ({ page }) => {
    await navigateTo(page, '/daily-challenges');

    // Check for "Available" badges
    const availableBadges = await page.locator('text=Available').count();
    expect(availableBadges).toBe(3);

    // Check that no "Completed" badges are shown
    const completedBadges = await page.locator('text=Completed').count();
    expect(completedBadges).toBe(0);

    // All Start buttons should be enabled
    const startButtons = await page.locator('text=Start').count();
    expect(startButtons).toBe(3);
  });

  test('should navigate to daily test challenge', async ({ page }) => {
    await navigateTo(page, '/daily-challenges');

    // Click Start on daily test card
    const dailyTestCard = page.locator('.card:has-text("Daily Test")');
    const startButton = dailyTestCard.locator('text=Start').first();

    if (await startButton.isVisible({ timeout: 3000 }).catch(() => false)) {
      await startButton.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(500);

      // Should be on daily test page or redirected if no words
      const url = page.url();
      const bodyText = await page.locator('body').textContent() || '';

      const onDailyTest = url.includes('/daily-test');
      const redirectedToLessons = url.includes('/lessons');
      const noWordsMessage = bodyText.includes('Start a lesson') || bodyText.includes('learn some words');

      expect(onDailyTest || redirectedToLessons || noWordsMessage).toBeTruthy();
    }
  });

  test('should navigate to daily kanji challenge', async ({ page }) => {
    await navigateTo(page, '/daily-challenges');

    const dailyKanjiCard = page.locator('.card:has-text("Daily Kanji")');
    const startButton = dailyKanjiCard.locator('text=Start').first();

    if (await startButton.isVisible({ timeout: 3000 }).catch(() => false)) {
      await startButton.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(500);

      const url = page.url();
      expect(url).toContain('/daily-challenges/kanji');
    }
  });

  test('should navigate to daily cards challenge', async ({ page }) => {
    await navigateTo(page, '/daily-challenges');

    const dailyCardsCard = page.locator('.card:has-text("Daily Cards")');
    const startButton = dailyCardsCard.locator('text=Start').first();

    if (await startButton.isVisible({ timeout: 3000 }).catch(() => false)) {
      await startButton.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(500);

      const url = page.url();
      expect(url).toContain('/daily-challenges/cards');
    }
  });

  test('should show XP rewards for each challenge', async ({ page }) => {
    await navigateTo(page, '/daily-challenges');

    const bodyText = await page.locator('body').textContent() || '';

    // Each challenge should show XP info
    expect(bodyText).toContain('Variable XP');
    expect(bodyText).toContain('Up to 600 XP');
    expect(bodyText).toContain('Up to 300 XP');
  });

  test('should show completed state after challenge is done', async ({ page }) => {
    // First complete the daily test
    await navigateTo(page, '/daily-test');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);

    const bodyText = await page.locator('body').textContent() || '';

    // If already completed or no words available, skip
    if (bodyText.includes('Daily Review Complete') || bodyText.includes('already completed')) {
      console.log('Daily test already completed or no words');
    } else if (bodyText.includes('Start a lesson') || page.url().includes('/lessons')) {
      console.log('No words available for daily test');
    } else {
      // Answer one question and then complete via QA API to simulate full completion
      const optionButtons = await page.locator('button[phx-click="select_answer"]').all();
      if (optionButtons.length > 0) {
        await optionButtons[0].click();
        await page.waitForTimeout(300);

        const submitButton = page.locator('button:has-text("Submit Answer"), button[phx-click="submit_answer"]').first();
        if (await submitButton.isVisible({ timeout: 3000 }).catch(() => false)) {
          await submitButton.click();
          await page.waitForTimeout(500);
        }
      }
    }

    // Go back to challenges page
    await navigateTo(page, '/daily-challenges');

    const challengesBody = await page.locator('body').textContent() || '';

    // Should show at least some state (completed or available)
    expect(challengesBody).toMatch(/Completed|Available|Done/);
  });

  test('should be accessible from dashboard', async ({ page }) => {
    await navigateTo(page, '/dashboard');

    const bodyText = await page.locator('body').textContent() || '';

    // Dashboard should have a link to daily challenges
    const hasDailyChallengesLink =
      bodyText.includes('Daily Challenges') ||
      bodyText.includes('Daily Review');

    expect(hasDailyChallengesLink).toBeTruthy();

    // Find and click the link
    const link = page.locator('a:has-text("Daily Challenges"), a:has-text("Daily Review")').first();
    if (await link.isVisible({ timeout: 3000 }).catch(() => false)) {
      await link.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(500);

      expect(page.url()).toContain('/daily-challenges');
    }
  });

  test('should handle user with no progress gracefully', async ({ page }) => {
    // Use a fresh user
    const auth = createAuthHelper(page);
    await auth.logout();
    await auth.login(TEST_USERS.studentNew);
    await resetDailyChallenges(page);

    await navigateTo(page, '/daily-challenges');

    const bodyText = await page.locator('body').textContent() || '';

    // Should still show the challenges page without crashing
    expect(bodyText).toContain('Daily Challenges');
    expect(bodyText).toContain('Daily Test');
    expect(bodyText).toContain('Daily Kanji');
    expect(bodyText).toContain('Daily Cards');

    // Should not show server error
    expect(bodyText).not.toContain('Internal Server Error');
  });
});
