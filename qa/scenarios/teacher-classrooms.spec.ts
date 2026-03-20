/**
 * Teacher Classroom Scenarios
 *
 * Tests for teacher classroom management.
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

test.describe('Teacher - Classroom Management', () => {
  test.use({ storageState: 'playwright/.auth/teacher.json' });

  test.beforeEach(async ({ page }) => {
    await navigateTo(page, 'teacherClassrooms');
  });

  test('teacher can view classrooms list', async ({ page }) => {
    await expect(page.locator('h1')).toContainText(/classrooms?/i);

    // Should see either classrooms or empty state
    const content = await page.locator('body').textContent();
    expect(content).toMatch(/classroom|create|no classrooms|get started/i);
  });

  test('teacher can create new classroom', async ({ page }) => {
    // Click create new classroom
    const createButton = page.locator('a:has-text("New"), a:has-text("Create"), button:has-text("Create")').first();

    if (await createButton.isVisible().catch(() => false)) {
      await createButton.click();

      // Should be on create page
      await expect(page.locator('h1')).toContainText(/create|new classroom/i);

      // Fill form
      const nameInput = page.locator('input[name="name"], input[name="classroom[name]"]');
      await nameInput.fill(`QA Test Classroom ${Date.now()}`);

      // Optional: fill description
      const descInput = page.locator('textarea[name="description"], textarea[name="classroom[description]"]');
      if (await descInput.isVisible().catch(() => false)) {
        await descInput.fill('This is a test classroom created by QA automation');
      }

      // Submit
      const submitButton = page.locator('button[type="submit"]').first();
      await submitButton.click();

      // Should redirect to classroom detail or list
      await page.waitForURL(/.*classrooms.*/, { timeout: 10000 });
    }
  });

  test('classroom shows invite code', async ({ page }) => {
    // If there are existing classrooms, check first one
    const classroomLinks = page.locator('a[href*="/teacher/classrooms/"]').all();
    const links = await classroomLinks;

    if (links.length > 0) {
      await links[0].click();

      // Look for invite code
      const inviteCode = page.locator('text=/invite|code|join/i');
      await expect(inviteCode.first()).toBeVisible();
    }
  });

  test('classroom shows tabs for different sections', async ({ page }) => {
    const classroomLinks = page.locator('a[href*="/teacher/classrooms/"]').all();
    const links = await classroomLinks;

    if (links.length > 0) {
      await links[0].click();

      // Look for tabs
      const tabs = page.locator('[role="tab"], .tab, a:has-text("Students"), a:has-text("Tests"), a:has-text("Lessons")');
      const tabCount = await tabs.count();
      expect(tabCount).toBeGreaterThan(0);
    }
  });
});

test.describe('Teacher - Test Creation', () => {
  test.use({ storageState: 'playwright/.auth/teacher.json' });

  test.beforeEach(async ({ page }) => {
    await navigateTo(page, 'teacherTests');
  });

  test('teacher can view tests list', async ({ page }) => {
    await expect(page.locator('h1')).toContainText(/tests?/i);
  });

  test('teacher can start creating a new test', async ({ page }) => {
    const createButton = page.locator('a:has-text("New Test"), a:has-text("Create"), button:has-text("Create")').first();

    if (await createButton.isVisible().catch(() => false)) {
      await createButton.click();

      // Should be on create page
      await expect(page.locator('h1')).toContainText(/create|new test/i);

      // Fill test name
      const nameInput = page.locator('input[name="name"], input[name="test[name]"]');
      await nameInput.fill(`QA Test ${Date.now()}`);

      // Continue or save
      const continueButton = page.locator('button:has-text("Continue"), button:has-text("Save"), button:has-text("Create")').first();
      await continueButton.click();

      // Should proceed to test builder
      await expect(page.locator('text=/steps?|questions?|builder/i').first()).toBeVisible();
    }
  });
});

test.describe('Student - Joining Classrooms', () => {
  test('student can navigate to join classroom page', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);

    await navigateTo(page, 'classroomJoin');

    await expect(page.locator('h1')).toContainText(/join|classroom/i);
  });

  test('student sees list of their classrooms', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);

    await navigateTo(page, 'classrooms');

    await expect(page.locator('h1')).toContainText(/classrooms?/i);
  });
});
