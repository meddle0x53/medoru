/**
 * User Profile Page Tests
 *
 * Tests for user profile display including:
 * - Profile information (name, avatar, bio)
 * - Stats display (streak, level, XP, kanji/words learned)
 * - Badges display
 * - Own profile vs other user's profile
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper } from '../helpers';

interface UserInfo {
  id: string;
  email: string;
  name: string;
  type: string;
}

async function getUserIdByEmail(page: any, email: string): Promise<string | null> {
  // Get user ID from the QA API
  const response = await page.request.get('/qa/bypass/api/users');
  if (response.ok()) {
    const data = await response.json();
    const users: UserInfo[] = data.users || [];
    const user = users.find((u: UserInfo) => u.email === email);
    return user?.id || null;
  }
  return null;
}

test.describe('User Profile Page', () => {
  
  test('should display own profile with all stats', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    // Get the actual UUID for this user
    const userId = await getUserIdByEmail(page, TEST_USERS.studentAdvanced.email);
    expect(userId).toBeTruthy();
    
    // Navigate to own profile using UUID
    await page.goto(`/users/${userId}`);
    await page.waitForLoadState('networkidle');
    
    // Verify profile page loaded
    const heading = page.locator('h1');
    await expect(heading).toBeVisible({ timeout: 10000 });
    
    const headingText = await heading.textContent() || '';
    console.log(`Profile heading: ${headingText}`);
    
    // Check for key profile elements
    const bodyText = await page.locator('body').textContent() || '';
    
    // Stats that should be displayed
    const expectedStats = [
      'Level',
      'Day Streak',
      'Kanji Learned',
      'Words Learned',
      'Learning Stats',
      'Total XP',
      'Tests Completed',
      'Longest Streak',
    ];
    
    const missingStats: string[] = [];
    for (const stat of expectedStats) {
      if (!bodyText.includes(stat)) {
        missingStats.push(stat);
        console.log(`❌ Missing stat: ${stat}`);
      } else {
        console.log(`✅ Found stat: ${stat}`);
      }
    }
    
    // Check for numeric values (not just "0" for active users)
    // studentAdvanced should have some progress
    const statsSection = page.locator('.card-body:has-text("Learning Stats")').first();
    if (await statsSection.isVisible({ timeout: 3000 }).catch(() => false)) {
      // Get the stats values
      const statCards = page.locator('.card:has(.text-2xl)');
      const count = await statCards.count();
      
      for (let i = 0; i < count; i++) {
        const card = statCards.nth(i);
        const value = await card.locator('.text-2xl').textContent().catch(() => 'N/A');
        const label = await card.locator('.text-sm').textContent().catch(() => 'N/A');
        console.log(`   Stat card ${i + 1}: ${label} = ${value}`);
      }
    }
    
    // Profile should load without errors
    expect(bodyText.includes('Internal Server Error')).toBeFalsy();
    expect(bodyText.includes('Error')).toBeFalsy();
    
    // All expected stats should be present
    expect(missingStats).toHaveLength(0);
  });

  test('should display correct streak information', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    // Get the actual UUID for this user
    const userId = await getUserIdByEmail(page, TEST_USERS.studentAdvanced.email);
    expect(userId).toBeTruthy();
    
    // Navigate to profile using UUID
    await page.goto(`/users/${userId}`);
    await page.waitForLoadState('networkidle');
    
    // Look for streak information
    const streakCard = page.locator('.card:has-text("Day Streak")');
    await expect(streakCard.first()).toBeVisible({ timeout: 10000 });
    
    // Get the streak value
    const streakValue = await streakCard.first()
      .locator('.text-2xl')
      .textContent()
      .catch(() => 'not found');
    
    console.log(`Current streak: ${streakValue}`);
    
    // studentAdvanced should have a streak (15 days based on seeds)
    // Verify it's a valid number
    const streakNum = parseInt(streakValue || '0', 10);
    expect(isNaN(streakNum)).toBeFalsy();
    
    // Also check longest streak
    const longestStreakRow = page.locator('.card:has-text("Learning Stats") .flex:has-text("Longest Streak")');
    if (await longestStreakRow.isVisible({ timeout: 3000 }).catch(() => false)) {
      const longestValue = await longestStreakRow.locator('.font-semibold').textContent().catch(() => '0');
      console.log(`Longest streak: ${longestValue}`);
      
      const longestNum = parseInt(longestValue || '0', 10);
      expect(isNaN(longestNum)).toBeFalsy();
      
      // Longest should be >= current
      expect(longestNum).toBeGreaterThanOrEqual(streakNum);
    }
  });

  test('should display user badges correctly', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    const userId = await getUserIdByEmail(page, TEST_USERS.studentAdvanced.email);
    expect(userId).toBeTruthy();
    
    await page.goto(`/users/${userId}`);
    await page.waitForLoadState('networkidle');
    
    // Check for badges section
    const badgesHeading = page.locator('h2:has-text("Badges")');
    const hasBadges = await badgesHeading.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (hasBadges) {
      console.log('✅ Badges section found');
      
      // Count badges
      const badgeElements = page.locator('.grid .flex:has(.hero-)');
      const badgeCount = await badgeElements.count();
      console.log(`   Found ${badgeCount} badges`);
      
      expect(badgeCount).toBeGreaterThan(0);
    } else {
      console.log('ℹ️ No badges section (user may have no badges)');
    }
  });

  test('should show different view for other user profile', async ({ page }) => {
    // Login as student
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Get studentAdvanced's UUID
    const otherUserId = await getUserIdByEmail(page, TEST_USERS.studentAdvanced.email);
    expect(otherUserId).toBeTruthy();
    
    // View studentAdvanced's profile
    await page.goto(`/users/${otherUserId}`);
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    
    // Should show the profile
    expect(bodyText.includes('Internal Server Error')).toBeFalsy();
    
    // Should see the user's name
    const heading = await page.locator('h1').textContent().catch(() => '');
    console.log(`Viewing profile: ${heading}`);
    
    // Stats should still be visible
    expect(bodyText.includes('Level')).toBeTruthy();
    expect(bodyText.includes('Day Streak')).toBeTruthy();
  });

  test('should handle non-existent user profile', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Try to access non-existent user (invalid UUID)
    await page.goto('/users/99999999-9999-9999-9999-999999999999');
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    const url = page.url();
    
    // Should redirect to home or show error
    const handled = 
      url === '/' ||
      bodyText.includes('User not found') ||
      bodyText.includes('not found') ||
      bodyText.includes('404');
    
    if (!handled) {
      console.log(`⚠️ Non-existent user handling: URL=${url}`);
    }
    
    // Should not crash
    expect(bodyText.includes('Internal Server Error')).toBeFalsy();
  });

  test('should handle invalid user ID', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Try to access with invalid ID format (not a UUID)
    await page.goto('/users/3');
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    
    // Should not crash with CastError
    expect(bodyText.includes('Internal Server Error')).toBeFalsy();
    expect(bodyText.includes('Ecto.Query.CastError')).toBeFalsy();
    
    // Should show error flash or redirect
    const hasError = 
      bodyText.includes('Invalid user ID') ||
      bodyText.includes('User not found') ||
      page.url() === '/';
    
    expect(hasError).toBeTruthy();
  });

  test('should display level and XP correctly', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    const userId = await getUserIdByEmail(page, TEST_USERS.studentAdvanced.email);
    expect(userId).toBeTruthy();
    
    await page.goto(`/users/${userId}`);
    await page.waitForLoadState('networkidle');
    
    // Check level card
    const levelCard = page.locator('.card:has-text("Level")');
    await expect(levelCard.first()).toBeVisible({ timeout: 10000 });
    
    const levelValue = await levelCard.first()
      .locator('.text-2xl')
      .textContent()
      .catch(() => 'not found');
    
    console.log(`User level: ${levelValue}`);
    
    const levelNum = parseInt(levelValue || '0', 10);
    expect(isNaN(levelNum)).toBeFalsy();
    expect(levelNum).toBeGreaterThanOrEqual(1);
    
    // Check XP in learning stats
    const xpRow = page.locator('.card:has-text("Learning Stats") .flex:has-text("Total XP")');
    if (await xpRow.isVisible({ timeout: 3000 }).catch(() => false)) {
      const xpValue = await xpRow.locator('.font-semibold').textContent().catch(() => '0');
      console.log(`Total XP: ${xpValue}`);
      
      const xpNum = parseInt(xpValue || '0', 10);
      expect(isNaN(xpNum)).toBeFalsy();
      expect(xpNum).toBeGreaterThanOrEqual(0);
    }
  });

  test('should display kanji and words learned counts', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    const userId = await getUserIdByEmail(page, TEST_USERS.studentAdvanced.email);
    expect(userId).toBeTruthy();
    
    await page.goto(`/users/${userId}`);
    await page.waitForLoadState('networkidle');
    
    // Check kanji learned
    const kanjiCard = page.locator('.card:has-text("Kanji Learned")');
    await expect(kanjiCard.first()).toBeVisible({ timeout: 10000 });
    
    const kanjiValue = await kanjiCard.first()
      .locator('.text-2xl')
      .textContent()
      .catch(() => 'not found');
    
    console.log(`Kanji learned: ${kanjiValue}`);
    
    const kanjiNum = parseInt(kanjiValue || '0', 10);
    expect(isNaN(kanjiNum)).toBeFalsy();
    
    // Check words learned
    const wordsCard = page.locator('.card:has-text("Words Learned")');
    await expect(wordsCard.first()).toBeVisible({ timeout: 10000 });
    
    const wordsValue = await wordsCard.first()
      .locator('.text-2xl')
      .textContent()
      .catch(() => 'not found');
    
    console.log(`Words learned: ${wordsValue}`);
    
    const wordsNum = parseInt(wordsValue || '0', 10);
    expect(isNaN(wordsNum)).toBeFalsy();
  });
});
