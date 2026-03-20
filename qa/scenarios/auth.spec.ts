/**
 * Authentication Scenarios
 *
 * Tests for login, logout, and access control.
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

test.describe('Authentication', () => {
  test('student can login via QA bypass', async ({ page }) => {
    const auth = createAuthHelper(page);

    await auth.login(TEST_USERS.student);

    // Verify logged in state
    await expect(page.locator('text=Dashboard')).toBeVisible();
    await expect(page).toHaveURL('/');
  });

  test('teacher can login and access teacher routes', async ({ page }) => {
    const auth = createAuthHelper(page);

    await auth.login(TEST_USERS.teacher);

    // Navigate to teacher section
    await navigateTo(page, 'teacherClassrooms');

    // Verify access granted
    await expect(page.locator('h1')).toContainText('Classrooms');
  });

  test('admin can login and access admin dashboard', async ({ page }) => {
    const auth = createAuthHelper(page);

    await auth.login(TEST_USERS.admin);

    // Navigate to admin section
    await navigateTo(page, 'admin');

    // Verify access granted
    await expect(page.locator('h1')).toContainText('Admin Dashboard');
  });

  test('student cannot access teacher routes', async ({ page }) => {
    const auth = createAuthHelper(page);

    await auth.login(TEST_USERS.student);

    // Try to access teacher section
    await navigateTo(page, 'teacherClassrooms');

    // Should be redirected or show access denied
    await expect(page.locator('body')).toContainText(/access denied|unauthorized|forbidden/i);
  });

  test('user can logout', async ({ page }) => {
    const auth = createAuthHelper(page);

    // Login first
    await auth.login(TEST_USERS.student);
    await expect(page.locator('text=Dashboard')).toBeVisible();

    // Logout
    await auth.logout();

    // Verify logged out - should not see dashboard link or should see sign in
    const body = page.locator('body');
    const isLoggedOut = await Promise.race([
      body.locator('text=Sign in').isVisible().catch(() => false),
      body.locator('text=Log in').isVisible().catch(() => false),
    ]);

    expect(isLoggedOut).toBeTruthy();
  });

  test('different user types have different navigation options', async ({ page }) => {
    const auth = createAuthHelper(page);

    // Test student navigation
    await auth.login(TEST_USERS.student);
    await page.goto('/');

    const studentNav = await page.locator('nav a').allTextContents();
    expect(studentNav.some((text) => text.includes('Dashboard'))).toBeTruthy();
    expect(studentNav.some((text) => text.includes('Lessons'))).toBeTruthy();

    // Logout and test teacher
    await auth.logout();
    await auth.login(TEST_USERS.teacher);
    await page.goto('/');

    const teacherNav = await page.locator('nav a').allTextContents();
    expect(teacherNav.some((text) => text.includes('Classrooms'))).toBeTruthy();
    expect(teacherNav.some((text) => text.includes('Tests'))).toBeTruthy();
  });
});

test.describe('QA Bypass Page', () => {
  test('QA bypass page shows all test users', async ({ page }) => {
    await page.goto('/qa/bypass');

    // Check page title
    await expect(page.locator('h1')).toContainText('QA Login Bypass');

    // Check that test users are displayed
    await expect(page.locator(`text=${TEST_USERS.admin.email}`)).toBeVisible();
    await expect(page.locator(`text=${TEST_USERS.teacher.email}`)).toBeVisible();
    await expect(page.locator(`text=${TEST_USERS.student.email}`)).toBeVisible();
  });

  test('can login via QA bypass UI', async ({ page }) => {
    await page.goto('/qa/bypass');

    // Click on a user
    await page.click(`button:has-text("${TEST_USERS.student.email}")`);

    // Should redirect to home and be logged in
    await expect(page).toHaveURL('/');
    await expect(page.locator('text=Dashboard')).toBeVisible();
  });
});
