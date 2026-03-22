/**
 * Performance Tests
 *
 * Measure and validate page load times, rendering performance,
 * and response times for key user interactions.
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper } from '../helpers';

// Performance thresholds (in milliseconds)
const THRESHOLDS = {
  pageLoad: 2000,        // Page should load in < 2s
  interactive: 1500,     // Page should be interactive in < 1.5s
  searchResponse: 500,   // Search should respond in < 500ms
  listRender: 1000,      // Lists should render in < 1s
  apiResponse: 500,      // API calls should respond in < 500ms (QA/debug mode)
};

test.describe('Performance Tests', () => {
  
  test('dashboard should load within threshold', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    // Measure navigation time
    const startTime = Date.now();
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    const loadTime = Date.now() - startTime;
    
    console.log(`Dashboard load time: ${loadTime}ms`);
    expect(loadTime).toBeLessThan(THRESHOLDS.pageLoad);
    
    // Check for key elements to ensure page is fully rendered
    const heading = page.locator('h1');
    await expect(heading).toBeVisible({ timeout: 5000 });
    
    // Check that stats cards are rendered
    const statsCards = page.locator('.card, [class*="stat"]').first();
    await expect(statsCards).toBeVisible({ timeout: 3000 });
  });

  test('lessons page should load and render list quickly', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    const startTime = Date.now();
    await page.goto('/lessons');
    await page.waitForLoadState('networkidle');
    const loadTime = Date.now() - startTime;
    
    console.log(`Lessons page load time: ${loadTime}ms`);
    expect(loadTime).toBeLessThan(THRESHOLDS.pageLoad);
    
    // Count lesson cards to verify rendering
    const lessonCards = page.locator('a[href*="/lessons/"]:not([href="/lessons"])');
    const cardCount = await lessonCards.count();
    console.log(`  Rendered ${cardCount} lesson cards`);
    
    // Each card should be visible
    if (cardCount > 0) {
      await expect(lessonCards.first()).toBeVisible({ timeout: 2000 });
    }
  });

  test('words list should render large datasets efficiently', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    // Navigate to words page
    const startTime = Date.now();
    await page.goto('/words');
    await page.waitForLoadState('networkidle');
    const loadTime = Date.now() - startTime;
    
    console.log(`Words list load time: ${loadTime}ms`);
    expect(loadTime).toBeLessThan(THRESHOLDS.pageLoad);
    
    // Count rendered word cards
    const wordCards = page.locator('a[href^="/words/"]').filter({ hasText: /./ });
    const cardCount = await wordCards.count();
    console.log(`  Rendered ${cardCount} word cards`);
    
    // Scroll to trigger any lazy loading
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(500);
    
    // Check that cards are still responsive after scroll
    if (cardCount > 0) {
      const firstCard = wordCards.first();
      await expect(firstCard).toBeVisible({ timeout: 2000 });
    }
  });

  test('kanji list should load and filter quickly', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    const startTime = Date.now();
    await page.goto('/kanji');
    await page.waitForLoadState('networkidle');
    const loadTime = Date.now() - startTime;
    
    console.log(`Kanji list load time: ${loadTime}ms`);
    expect(loadTime).toBeLessThan(THRESHOLDS.pageLoad);
    
    // Test N5 filter performance
    const n5Tab = page.locator('a:has-text("N5")').first();
    if (await n5Tab.isVisible({ timeout: 3000 }).catch(() => false)) {
      const filterStart = Date.now();
      await n5Tab.click();
      await page.waitForLoadState('networkidle');
      const filterTime = Date.now() - filterStart;
      
      console.log(`  N5 filter time: ${filterTime}ms`);
      expect(filterTime).toBeLessThan(THRESHOLDS.searchResponse);
    }
    
    // Count kanji cards
    const kanjiCards = page.locator('a[href^="/kanji/"]').filter({ hasText: /[\u4e00-\u9faf]/ });
    const cardCount = await kanjiCards.count();
    console.log(`  Rendered ${cardCount} kanji cards`);
  });

  test('search should respond quickly', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    await page.goto('/words');
    await page.waitForLoadState('networkidle');
    
    const searchInput = page.locator('input[type="search"], input[placeholder*="search" i]').first();
    if (!(await searchInput.isVisible({ timeout: 5000 }).catch(() => false))) {
      console.log('⚠️ No search input found');
      return;
    }
    
    // Type search query and measure response
    const searchStart = Date.now();
    await searchInput.fill('hello');
    await searchInput.press('Enter');
    await page.waitForLoadState('networkidle');
    const searchTime = Date.now() - searchStart;
    
    console.log(`Search response time: ${searchTime}ms`);
    expect(searchTime).toBeLessThan(THRESHOLDS.searchResponse * 3); // Allow 3x for search
    
    // Clear search
    const clearButton = page.locator('button:has-text("Clear"), button[phx-click="clear_search"]').first();
    if (await clearButton.isVisible({ timeout: 2000 }).catch(() => false)) {
      const clearStart = Date.now();
      await clearButton.click();
      await page.waitForLoadState('networkidle');
      const clearTime = Date.now() - clearStart;
      
      console.log(`  Clear search time: ${clearTime}ms`);
    }
  });

  test('profile page should load quickly', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    // Get user ID from API
    const response = await page.request.get('/qa/bypass/api/users');
    const data = await response.json();
    const user = data.users.find((u: any) => u.email === TEST_USERS.studentAdvanced.email);
    
    if (!user) {
      console.log('⚠️ User not found in API');
      return;
    }
    
    const startTime = Date.now();
    await page.goto(`/users/${user.id}`);
    await page.waitForLoadState('networkidle');
    const loadTime = Date.now() - startTime;
    
    console.log(`Profile page load time: ${loadTime}ms`);
    expect(loadTime).toBeLessThan(THRESHOLDS.pageLoad);
    
    // Check that stats are rendered
    const statsSection = page.locator('.card:has-text("Level"), .card:has-text("Streak")').first();
    await expect(statsSection).toBeVisible({ timeout: 3000 });
  });

  test('API endpoints should respond quickly', async ({ page }) => {
    // Test health endpoint
    const healthStart = Date.now();
    const healthResponse = await page.request.get('/qa/health');
    const healthTime = Date.now() - healthStart;
    
    console.log(`Health API response time: ${healthTime}ms`);
    expect(healthTime).toBeLessThan(THRESHOLDS.apiResponse);
    expect(healthResponse.ok()).toBeTruthy();
    
    // Test users API
    const usersStart = Date.now();
    const usersResponse = await page.request.get('/qa/bypass/api/users');
    const usersTime = Date.now() - usersStart;
    
    console.log(`Users API response time: ${usersTime}ms`);
    expect(usersTime).toBeLessThan(THRESHOLDS.apiResponse * 2); // Allow 2x for data
    expect(usersResponse.ok()).toBeTruthy();
  });

  test('navigation between pages should be fast', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    // Start at dashboard
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    // Navigate to lessons
    const lessonsNavStart = Date.now();
    await page.click('a:has-text("Lessons")');
    await page.waitForLoadState('networkidle');
    const lessonsNavTime = Date.now() - lessonsNavStart;
    
    console.log(`Dashboard → Lessons navigation: ${lessonsNavTime}ms`);
    expect(lessonsNavTime).toBeLessThan(THRESHOLDS.interactive);
    
    // Navigate to words
    const wordsNavStart = Date.now();
    await page.click('a:has-text("Words")');
    await page.waitForLoadState('networkidle');
    const wordsNavTime = Date.now() - wordsNavStart;
    
    console.log(`Lessons → Words navigation: ${wordsNavTime}ms`);
    expect(wordsNavTime).toBeLessThan(THRESHOLDS.interactive);
    
    // Navigate to kanji
    const kanjiNavStart = Date.now();
    await page.click('a:has-text("Kanji")');
    await page.waitForLoadState('networkidle');
    const kanjiNavTime = Date.now() - kanjiNavStart;
    
    console.log(`Words → Kanji navigation: ${kanjiNavTime}ms`);
    expect(kanjiNavTime).toBeLessThan(THRESHOLDS.interactive);
  });

  test('mobile viewport performance', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    const startTime = Date.now();
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    const loadTime = Date.now() - startTime;
    
    console.log(`Mobile dashboard load time: ${loadTime}ms`);
    expect(loadTime).toBeLessThan(THRESHOLDS.pageLoad * 1.5); // Allow 1.5x on mobile
    
    // Check mobile menu
    const menuButton = page.locator('button:has-text("Menu"), button[aria-label*="menu" i]').first();
    if (await menuButton.isVisible({ timeout: 3000 }).catch(() => false)) {
      const menuStart = Date.now();
      await menuButton.click();
      await page.waitForTimeout(300);
      const menuTime = Date.now() - menuStart;
      
      console.log(`  Mobile menu open time: ${menuTime}ms`);
    }
  });

  test('should handle rapid interactions', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    await page.goto('/lessons');
    await page.waitForLoadState('networkidle');
    
    // Rapid tab switching
    const tabs = ['N5', 'N4', 'N3'];
    const tabTimes: number[] = [];
    
    for (const tab of tabs) {
      const tabLink = page.locator(`a:has-text("${tab}")`).first();
      if (await tabLink.isVisible({ timeout: 2000 }).catch(() => false)) {
        const start = Date.now();
        await tabLink.click();
        await page.waitForTimeout(200); // Minimum wait for UI update
        tabTimes.push(Date.now() - start);
      }
    }
    
    if (tabTimes.length > 0) {
      const avgTime = tabTimes.reduce((a, b) => a + b, 0) / tabTimes.length;
      console.log(`Average tab switch time: ${avgTime.toFixed(0)}ms`);
      expect(avgTime).toBeLessThan(THRESHOLDS.searchResponse);
    }
  });

  test('memory usage should be reasonable', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    // Navigate through multiple pages
    const pages = ['/dashboard', '/lessons', '/words', '/kanji'];
    
    for (const url of pages) {
      await page.goto(url);
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(500);
    }
    
    // Get performance metrics if available
    const metrics = await page.evaluate(() => {
      const perf = performance as any;
      return {
        usedJSHeapSize: perf.memory?.usedJSHeapSize,
        totalJSHeapSize: perf.memory?.totalJSHeapSize,
      };
    }).catch(() => ({}));
    
    if (metrics.usedJSHeapSize) {
      const usedMB = metrics.usedJSHeapSize / 1024 / 1024;
      console.log(`JS Heap used: ${usedMB.toFixed(2)}MB`);
      
      // Should use less than 100MB
      expect(usedMB).toBeLessThan(100);
    }
  });
});
