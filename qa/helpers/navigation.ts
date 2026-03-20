/**
 * Navigation helpers for Medoru QA testing
 */

import { Page, Locator } from '@playwright/test';

/**
 * Common navigation paths in Medoru
 */
export const PATHS = {
  // Public
  home: '/',
  kanji: '/kanji',
  words: '/words',
  lessons: '/lessons',

  // Auth
  login: '/qa/bypass',
  logout: '/auth/logout',

  // Authenticated
  dashboard: '/dashboard',
  dailyTest: '/daily-test',
  dailyReview: '/daily-review',
  notifications: '/notifications',

  // Settings
  settingsProfile: '/settings/profile',
  settingsLanguage: '/settings/language',

  // Teacher
  teacherClassrooms: '/teacher/classrooms',
  teacherTests: '/teacher/tests',
  teacherCustomLessons: '/teacher/custom-lessons',

  // Student classrooms
  classrooms: '/classrooms',
  classroomJoin: '/classrooms/join',

  // Admin
  admin: '/admin',
  adminUsers: '/admin/users',
  adminKanji: '/admin/kanji',
  adminWords: '/admin/words',
  adminLessons: '/admin/lessons',
} as const;

export type PathKey = keyof typeof PATHS;

/**
 * Navigate to a specific page
 */
export async function navigateTo(page: Page, path: PathKey | string): Promise<void> {
  const url = PATHS[path as PathKey] || path;
  await page.goto(url);
  await page.waitForLoadState('networkidle');
  // Additional wait for LiveView to fully mount
  await page.waitForTimeout(500);
}

/**
 * Wait for page to be fully loaded
 */
export async function waitForPageLoad(page: Page): Promise<void> {
  await page.waitForLoadState('networkidle');
  await page.waitForLoadState('domcontentloaded');
}

/**
 * Get the current page title
 */
export async function getPageTitle(page: Page): Promise<string> {
  return await page.title();
}

/**
 * Check if current URL matches expected path
 */
export async function isOnPage(page: Page, path: string): Promise<boolean> {
  const currentUrl = page.url();
  const expectedUrl = new URL(path, page.url()).toString();
  return currentUrl === expectedUrl || currentUrl.endsWith(path);
}

/**
 * Wait for URL to change to expected path
 */
export async function waitForNavigation(
  page: Page,
  path: string,
  timeout = 10000
): Promise<void> {
  await page.waitForURL(`**${path}`, { timeout });
}

/**
 * Click a navigation link and wait for navigation
 */
export async function clickNavLink(
  page: Page,
  linkText: string,
  expectedPath?: string
): Promise<void> {
  const link = page.locator(`nav a:has-text("${linkText}"), [role="navigation"] a:has-text("${linkText}")`);
  await link.click();

  if (expectedPath) {
    await waitForNavigation(page, expectedPath);
  } else {
    await page.waitForLoadState('networkidle');
  }
}

/**
 * Open mobile navigation menu
 */
export async function openMobileNav(page: Page): Promise<void> {
  const menuButton = page.locator('[data-testid="mobile-menu-button"], button[aria-label*="menu"], button[aria-label*="Menu"]').first();
  if (await menuButton.isVisible({ timeout: 3000 }).catch(() => false)) {
    await menuButton.click();
    // Wait for menu to open
    await page.waitForTimeout(300);
  }
}

/**
 * Navigate via mobile menu
 */
export async function navigateViaMobileMenu(page: Page, linkText: string): Promise<void> {
  await openMobileNav(page);
  const link = page.locator(`nav a:has-text("${linkText}")`).last();
  await link.click();
  await page.waitForLoadState('networkidle');
}

/**
 * Get all visible navigation links
 */
export async function getNavLinks(page: Page): Promise<string[]> {
  const links = page.locator('nav a, [role="navigation"] a');
  return await links.allTextContents();
}

/**
 * Navigate to a lesson and wait for it to load
 */
export async function goToLesson(page: Page, lessonId: string | number): Promise<void> {
  await navigateTo(page, `/lessons/${lessonId}`);
  await page.waitForSelector('[data-testid="lesson-content"], h1', { timeout: 10000 });
}

/**
 * Navigate to a kanji detail page
 */
export async function goToKanji(page: Page, kanjiId: string | number): Promise<void> {
  await navigateTo(page, `/kanji/${kanjiId}`);
  await page.waitForSelector('[data-testid="kanji-detail"], h1', { timeout: 10000 });
}

/**
 * Navigate to classroom
 */
export async function goToClassroom(page: Page, classroomId: string): Promise<void> {
  await navigateTo(page, `/classrooms/${classroomId}`);
  await page.waitForSelector('[data-testid="classroom-detail"], h1', { timeout: 10000 });
}
