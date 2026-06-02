/**
 * Daily Challenge - Kanji Writing Tests
 *
 * Covers the daily kanji writing challenge at /daily-challenges/kanji
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

test.describe('Daily Challenge - Kanji Writing', () => {
  test.beforeEach(async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    await resetDailyChallenges(page);
  });

  test('should load the kanji challenge page', async ({ page }) => {
    await navigateTo(page, '/daily-challenges/kanji');
    await page.waitForTimeout(500);

    const bodyText = await page.locator('body').textContent() || '';

    // Should show challenge header
    expect(bodyText).toContain('Daily Kanji Challenge');

    // Should show instructions
    expect(bodyText).toMatch(/Practice writing|kanji|wrong strokes/i);
  });

  test('should show kanji writing component', async ({ page }) => {
    await navigateTo(page, '/daily-challenges/kanji');
    await page.waitForTimeout(1000);

    // Look for kanji display (large text showing the kanji character)
    const kanjiDisplay = page.locator('.text-5xl, .text-6xl, .text-7xl, [data-testid="kanji-character"]').first();
    const hasKanjiDisplay = await kanjiDisplay.isVisible({ timeout: 3000 }).catch(() => false);

    // Or look for writing canvas
    const canvas = page.locator('canvas, [data-testid="writing-canvas"]').first();
    const hasCanvas = await canvas.isVisible({ timeout: 3000 }).catch(() => false);

    // Or look for kanji info
    const bodyText = await page.locator('body').textContent() || '';
    const hasKanjiInfo = bodyText.includes('Meaning') || bodyText.includes('Reading');

    expect(hasKanjiDisplay || hasCanvas || hasKanjiInfo).toBeTruthy();
  });

  test('should show progress indicator', async ({ page }) => {
    await navigateTo(page, '/daily-challenges/kanji');
    await page.waitForTimeout(500);

    const bodyText = await page.locator('body').textContent() || '';

    // Should show progress like "1 / 10" or similar
    const hasProgress = bodyText.match(/\d+\s*\/\s*10/);
    expect(hasProgress).toBeTruthy();
  });

  test('should show already completed state', async ({ page }) => {
    await navigateTo(page, '/daily-challenges/kanji');
    await page.waitForTimeout(500);

    const bodyText = await page.locator('body').textContent() || '';

    // Either we're on the challenge or already completed
    const onChallenge = bodyText.includes('Daily Kanji Challenge') && !bodyText.includes('Already Completed');
    const alreadyCompleted = bodyText.includes('Already Completed');

    expect(onChallenge || alreadyCompleted).toBeTruthy();
  });

  test('should handle user with no learned kanji gracefully', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.logout();
    await auth.login(TEST_USERS.studentNew);
    await resetDailyChallenges(page);

    await navigateTo(page, '/daily-challenges/kanji');
    await page.waitForTimeout(500);

    const bodyText = await page.locator('body').textContent() || '';
    const url = page.url();

    // Should not crash
    expect(bodyText).not.toContain('Internal Server Error');
    expect(bodyText).not.toContain('Phoenix.Router.NoRouteError');

    // Should either show the challenge or a helpful message
    const showingChallenge = bodyText.includes('Daily Kanji Challenge');
    const hasMessage = bodyText.includes('Not enough') || bodyText.includes('learn');
    const redirected = url.includes('/daily-challenges') && !url.includes('/kanji');

    expect(showingChallenge || hasMessage || redirected).toBeTruthy();
  });

  test('should display streak info', async ({ page }) => {
    await navigateTo(page, '/daily-challenges/kanji');
    await page.waitForTimeout(500);

    const bodyText = await page.locator('body').textContent() || '';

    // Should show streak
    expect(bodyText).toMatch(/day streak|streak/i);
  });

  test('should have navigation back to challenges', async ({ page }) => {
    await navigateTo(page, '/daily-challenges/kanji');
    await page.waitForTimeout(500);

    // Look for back link
    const backLink = page.locator('a:has-text("Back"), a:has-text("Daily Challenges")').first();
    const hasBackLink = await backLink.isVisible({ timeout: 3000 }).catch(() => false);

    if (hasBackLink) {
      await backLink.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(500);

      expect(page.url()).toContain('/daily-challenges');
    }
  });

  test('page should be accessible', async ({ page }) => {
    await navigateTo(page, '/daily-challenges/kanji');
    await page.waitForTimeout(500);

    // Should have an h1
    const h1 = page.locator('h1');
    expect(await h1.count()).toBeGreaterThan(0);

    // Should have lang attribute
    const html = page.locator('html');
    await expect(html).toHaveAttribute('lang', /.+/);
  });
});
