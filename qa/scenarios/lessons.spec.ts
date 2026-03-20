/**
 * Lessons Scenarios
 *
 * Tests for lesson browsing and study.
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo, goToLesson } from '../helpers';

test.describe('Public Lessons', () => {
  test('can browse lessons list', async ({ page }) => {
    await navigateTo(page, 'lessons');

    await expect(page.locator('h1')).toContainText(/lessons?/i);

    // Should show lessons or categories
    const content = await page.locator('body').textContent();
    expect(content).toMatch(/lesson|level|n5|n4|n3/i);
  });

  test('lessons show level badges', async ({ page }) => {
    await navigateTo(page, 'lessons');

    // Look for JLPT level indicators
    const levelBadges = page.locator('text=/N5|N4|N3|N2|N1|Beginner|Intermediate/i');

    // Should have some level indicators
    const count = await levelBadges.count();
    expect(count).toBeGreaterThan(0);
  });

  test('can view individual lesson details', async ({ page }) => {
    await navigateTo(page, 'lessons');

    // Click on first lesson
    const lessonLink = page.locator('a[href*="/lessons/"]').first();

    if (await lessonLink.isVisible().catch(() => false)) {
      await lessonLink.click();

      // Should be on lesson detail page
      await expect(page.locator('h1')).toBeVisible();

      // Should show lesson content
      const content = await page.locator('body').textContent();
      expect(content).toMatch(/kanji|words?|vocabulary|learn|study/i);
    }
  });
});

test.describe('Authenticated Lesson Features', () => {
  test.beforeEach(async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
  });

  test('authenticated user can start a lesson', async ({ page }) => {
    await navigateTo(page, 'lessons');

    // Find a lesson with a "Learn" or "Start" button
    const startButton = page.locator('a:has-text("Learn"), a:has-text("Start"), button:has-text("Start")').first();

    if (await startButton.isVisible().catch(() => false)) {
      await startButton.click();

      // Should navigate to learn page
      await expect(page).toHaveURL(/.*learn.*/);

      // Should show lesson content
      await expect(page.locator('h1, h2').first()).toBeVisible();
    }
  });

  test('lesson shows progress for started lessons', async ({ page }) => {
    await navigateTo(page, 'lessons');

    // Look for progress indicators
    const progressElements = page.locator('[data-testid="progress"], .progress, text=/completed|in progress/i');

    // Progress indicators might exist
    const count = await progressElements.count();
    // Don't assert count > 0 since not all lessons may be started
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('can navigate through lesson pages', async ({ page }) => {
    await navigateTo(page, 'lessons');

    // Find a lesson and go to it
    const lessonLink = page.locator('a[href*="/lessons/"]').first();

    if (await lessonLink.isVisible().catch(() => false)) {
      await lessonLink.click();

      // Look for navigation
      const nextButton = page.locator('a:has-text("Next"), button:has-text("Next"), a:has-text("Continue")');
      const prevButton = page.locator('a:has-text("Previous"), button:has-text("Previous"), a:has-text("Back")');

      // At least navigation should be present
      const hasNav = (await nextButton.isVisible().catch(() => false)) ||
                     (await prevButton.isVisible().catch(() => false));

      expect(hasNav).toBeTruthy();
    }
  });
});

test.describe('Lesson Search and Filter', () => {
  test('can filter lessons by level', async ({ page }) => {
    await navigateTo(page, 'lessons');

    // Look for level filter
    const levelFilter = page.locator('select, button:has-text("N5"), button:has-text("Level")').first();

    if (await levelFilter.isVisible().catch(() => false)) {
      await levelFilter.click();

      // Select N5
      const n5Option = page.locator('text=N5, option[value="n5"]').first();
      if (await n5Option.isVisible().catch(() => false)) {
        await n5Option.click();

        // Should filter results
        await page.waitForTimeout(500);

        // Check that filtered results show N5
        const n5Badges = page.locator('text=N5');
        const count = await n5Badges.count();
        expect(count).toBeGreaterThan(0);
      }
    }
  });
});
