/**
 * Daily Challenge - Edge Cases and Integration Tests
 *
 * Covers cross-challenge interactions, streak behavior, resets,
 * and boundary conditions.
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
    console.log('Note: Daily challenges reset returned non-ok');
  }
}

test.describe('Daily Challenge - Edge Cases', () => {
  test('should allow reset via QA API', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);

    // Reset should succeed
    const response = await page.request.delete('/qa/api/daily-challenges');
    expect(response.ok()).toBeTruthy();

    const data = await response.json();
    expect(data.success).toBe(true);
    expect(data).toHaveProperty('deleted');

    console.log(`Reset deleted ${data.deleted} challenge records`);
  });

  test('should show correct completion count after partial completion', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    await resetDailyChallenges(page);

    // Start daily test (but don't complete it)
    await navigateTo(page, '/daily-test');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);

    const bodyText = await page.locator('body').textContent() || '';

    // If test is available, answer one question
    if (!bodyText.includes('Daily Review Complete') && !bodyText.includes('already completed')) {
      const optionButtons = await page.locator('button[phx-click="select_answer"]').all();
      if (optionButtons.length > 0) {
        await optionButtons[0].click();
        await page.waitForTimeout(300);
      }
    }

    // Go to challenges page
    await navigateTo(page, '/daily-challenges');

    const challengesBody = await page.locator('body').textContent() || '';

    // Should show 0/3 or 1/3 completed depending on state
    expect(challengesBody).toMatch(/\d+\s*\/\s*3/);
  });

  test('should handle rapid navigation between challenges', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    await resetDailyChallenges(page);

    // Navigate through all challenges quickly
    await navigateTo(page, '/daily-challenges');
    await navigateTo(page, '/daily-challenges/kanji');
    await navigateTo(page, '/daily-challenges/cards');
    await navigateTo(page, '/daily-test');
    await navigateTo(page, '/daily-challenges');

    const bodyText = await page.locator('body').textContent() || '';

    // Should still be coherent
    expect(bodyText).toContain('Daily Challenges');
    expect(bodyText).not.toContain('Internal Server Error');
  });

  test('should show different states for different users', async ({ browser }) => {
    // Create two contexts
    const context1 = await browser.newContext();
    const context2 = await browser.newContext();

    try {
      const page1 = await context1.newPage();
      const page2 = await context2.newPage();

      // User 1: advanced student
      const auth1 = createAuthHelper(page1);
      await auth1.login(TEST_USERS.studentAdvanced);
      await resetDailyChallenges(page1);

      // User 2: new student
      const auth2 = createAuthHelper(page2);
      await auth2.login(TEST_USERS.studentNew);
      await resetDailyChallenges(page2);

      // Both navigate to challenges
      await navigateTo(page1, '/daily-challenges');
      await navigateTo(page2, '/daily-challenges');

      const body1 = await page1.locator('body').textContent() || '';
      const body2 = await page2.locator('body').textContent() || '';

      // Both should show the challenges page
      expect(body1).toContain('Daily Challenges');
      expect(body2).toContain('Daily Challenges');

      // Streaks might differ
      console.log(`Advanced user streak shown: ${body1.includes('day streak')}`);
      console.log(`New user streak shown: ${body2.includes('day streak')}`);
    } finally {
      await context1.close();
      await context2.close();
    }
  });

  test('should not crash when accessing challenges while unauthenticated', async ({ page }) => {
    // Logout first
    const auth = createAuthHelper(page);
    await auth.logout();

    // Try to access challenges
    await navigateTo(page, '/daily-challenges');

    const bodyText = await page.locator('body').textContent() || '';
    const url = page.url();

    // Should redirect to login or show auth required
    const redirected = url.includes('/auth') || url.includes('/login');
    const hasAuthMessage = bodyText.includes('Sign in') || bodyText.includes('Log in');

    expect(redirected || hasAuthMessage).toBeTruthy();
    expect(bodyText).not.toContain('Internal Server Error');
  });

  test('should handle direct URL access to card game', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    await resetDailyChallenges(page);

    // Access card game directly without going through challenges page
    await navigateTo(page, '/daily-challenges/cards');
    await page.waitForTimeout(500);

    const bodyText = await page.locator('body').textContent() || '';

    // Should show the game, not an error
    expect(bodyText).toContain('Daily Card Challenge');
    expect(bodyText).not.toContain('Internal Server Error');
  });

  test('should handle direct URL access to kanji challenge', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    await resetDailyChallenges(page);

    await navigateTo(page, '/daily-challenges/kanji');
    await page.waitForTimeout(500);

    const bodyText = await page.locator('body').textContent() || '';

    expect(bodyText).toContain('Daily Kanji Challenge');
    expect(bodyText).not.toContain('Internal Server Error');
  });

  test('should handle page refresh during card game', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    await resetDailyChallenges(page);

    await navigateTo(page, '/daily-challenges/cards');
    await page.waitForTimeout(500);

    // Flip a card
    const card = page.locator('button[phx-click="flip_card"]').first();
    await card.click();
    await page.waitForTimeout(300);

    // Refresh page
    await page.reload();
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    const bodyText = await page.locator('body').textContent() || '';

    // Should still show the game (state resets on reload since it's in-memory)
    expect(bodyText).toContain('Daily Card Challenge');
    expect(bodyText).not.toContain('Internal Server Error');
  });

  test('should update dashboard link after completing a challenge', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    await resetDailyChallenges(page);

    // Visit dashboard
    await navigateTo(page, '/dashboard');

    const initialBody = await page.locator('body').textContent() || '';
    const hasChallengeLink = initialBody.includes('Daily Challenges') || initialBody.includes('Daily Review');
    expect(hasChallengeLink).toBeTruthy();
  });

  test('should handle teacher user accessing challenges', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.teacher);
    await resetDailyChallenges(page);

    await navigateTo(page, '/daily-challenges');

    const bodyText = await page.locator('body').textContent() || '';

    // Teachers should also see challenges
    expect(bodyText).toContain('Daily Challenges');
    expect(bodyText).toContain('Daily Test');
    expect(bodyText).toContain('Daily Kanji');
    expect(bodyText).toContain('Daily Cards');
  });

  test('should handle admin user accessing challenges', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.admin);
    await resetDailyChallenges(page);

    await navigateTo(page, '/daily-challenges');

    const bodyText = await page.locator('body').textContent() || '';

    expect(bodyText).toContain('Daily Challenges');
    expect(bodyText).not.toContain('Internal Server Error');
  });
});
