/**
 * Smoke Test Suite
 *
 * Quick validation of core features. Runs faster than full E2E tests.
 * Use this to verify the application is working before running longer tests.
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo, expectHeading } from '../helpers';

test.describe('Smoke Tests', () => {
  test.describe('Public Pages', () => {
    test('homepage loads', async ({ page }) => {
      await page.goto('/');
      await page.waitForLoadState('networkidle');
      await expectHeading(page, /medoru|learn|japanese/i);
    });

    test('kanji page loads', async ({ page }) => {
      await navigateTo(page, 'kanji');
      await expectHeading(page, /kanji/i);
    });

    test('lessons page loads', async ({ page }) => {
      await navigateTo(page, 'lessons');
      await expectHeading(page, /lessons?/i);
    });

    test('words page loads', async ({ page }) => {
      await navigateTo(page, 'words');
      await expectHeading(page, /words?|vocabulary/i);
    });
  });

  test.describe('Authentication', () => {
    test('student can login via QA bypass', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.student);
      
      // Check we're on a page that shows authenticated state
      await page.waitForLoadState('networkidle');
      const bodyText = await page.locator('body').textContent();
      expect(bodyText).toMatch(/dashboard|classrooms|settings|logout/i);
    });

    test('teacher can login via QA bypass', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.teacher);
      
      await page.waitForLoadState('networkidle');
      const bodyText = await page.locator('body').textContent();
      expect(bodyText).toMatch(/classrooms|tests|dashboard/i);
    });

    test('admin can login via QA bypass', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.admin);
      
      await page.waitForLoadState('networkidle');
      const bodyText = await page.locator('body').textContent();
      expect(bodyText).toMatch(/admin|dashboard|classrooms/i);
    });
  });

  test.describe('Student Features', () => {
    test.use({ storageState: 'playwright/.auth/user.json' });

    test('dashboard loads', async ({ page }) => {
      await navigateTo(page, 'dashboard');
      await page.waitForLoadState('networkidle');
      // Dashboard may have various titles, just check it loads
      await expect(page.locator('body')).toContainText(/dashboard|welcome|continue|study/i);
    });

    test('classrooms page loads', async ({ page }) => {
      await navigateTo(page, 'classrooms');
      await page.waitForLoadState('networkidle');
      await expect(page.locator('h1')).toContainText(/classrooms?/i);
    });

    test('daily review page loads', async ({ page }) => {
      await navigateTo(page, 'dailyReview');
      await page.waitForLoadState('networkidle');
      // Daily review might show different states
      const bodyText = await page.locator('body').textContent();
      expect(bodyText).toMatch(/review|daily|test|complete|start/i);
    });
  });

  test.describe('Teacher Features', () => {
    test.use({ storageState: 'playwright/.auth/teacher.json' });

    test('teacher classrooms page loads', async ({ page }) => {
      await navigateTo(page, 'teacherClassrooms');
      await page.waitForLoadState('networkidle');
      await expect(page.locator('h1')).toContainText(/classrooms?/i);
    });

    test('teacher tests page loads', async ({ page }) => {
      await navigateTo(page, 'teacherTests');
      await page.waitForLoadState('networkidle');
      await expect(page.locator('h1')).toContainText(/tests?/i);
    });

    test('teacher custom lessons page loads', async ({ page }) => {
      await navigateTo(page, 'teacherCustomLessons');
      await page.waitForLoadState('networkidle');
      await expect(page.locator('h1')).toContainText(/lessons?|custom/i);
    });
  });

  test.describe('Admin Features', () => {
    test.use({ storageState: 'playwright/.auth/admin.json' });

    test('admin dashboard loads', async ({ page }) => {
      await navigateTo(page, 'admin');
      await page.waitForLoadState('networkidle');
      await expect(page.locator('h1')).toContainText(/admin/i);
    });

    test('admin users page loads', async ({ page }) => {
      await navigateTo(page, 'adminUsers');
      await page.waitForLoadState('networkidle');
      await expect(page.locator('h1')).toContainText(/users?/i);
    });
  });

  test.describe('QA Features', () => {
    test('QA bypass page loads', async ({ page }) => {
      await page.goto('/qa/bypass');
      await page.waitForLoadState('networkidle');
      await expect(page.locator('h1')).toContainText(/qa|bypass|login/i);
      await expect(page.locator(`text=${TEST_USERS.student.email}`)).toBeVisible();
    });

    test('QA health endpoint responds', async ({ request }) => {
      const response = await request.get('/qa/health');
      expect(response.ok()).toBeTruthy();
      
      const body = await response.json();
      expect(body.status).toBe('ok');
      expect(body.environment).toBe('qa');
    });

    test('QA users API responds', async ({ request }) => {
      const response = await request.get('/qa/bypass/api/users');
      expect(response.ok()).toBeTruthy();
      
      const body = await response.json();
      expect(body.users).toBeInstanceOf(Array);
      expect(body.users.length).toBeGreaterThan(0);
    });

    test('QA API login works', async ({ request }) => {
      const response = await request.post('/qa/bypass/api/login', {
        data: { email: TEST_USERS.student.email },
      });
      
      expect(response.ok()).toBeTruthy();
      
      const body = await response.json();
      expect(body.success).toBe(true);
      expect(body.user.email).toBe(TEST_USERS.student.email);
    });
  });
});

/**
 * Run this with:
 * npx playwright test scenarios/smoke-test.spec.ts
 * 
 * For faster execution (one browser):
 * npx playwright test scenarios/smoke-test.spec.ts --project=chromium
 */
