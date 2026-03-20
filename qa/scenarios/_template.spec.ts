/**
 * Scenario Template
 *
 * Use this as a starting point for creating new QA scenarios.
 * Copy this file and modify it for your specific test case.
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo, expectFlashMessage } from '../helpers';

/**
 * Scenario: [Brief description of what this test covers]
 *
 * Preconditions:
 * - [What needs to be set up before the test]
 *
 * Steps:
 * 1. [Step 1 description]
 * 2. [Step 2 description]
 * 3. [Step 3 description]
 *
 * Expected Result:
 * - [What should happen]
 */
test.describe('Feature: [Name]', () => {
  // Use pre-authenticated session for tests that need to start logged in
  // test.use({ storageState: 'playwright/.auth/student.json' });

  test('should [describe what should happen]', async ({ page }) => {
    // Arrange - Login and navigate
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    await navigateTo(page, 'dashboard');

    // Act - Perform the action
    // ... your test actions here

    // Assert - Verify the result
    await expect(page.locator('h1')).toContainText('Expected Title');
  });

  test('should handle [error case]', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);

    // Test error handling
    await expectFlashMessage(page, /error|failed/i, 'error');
  });
});

/**
 * Multi-step workflow example
 */
test.describe('Workflow: [Name]', () => {
  test('complete workflow from start to finish', async ({ page }) => {
    const auth = createAuthHelper(page);
    
    // Step 1: Login
    await auth.login(TEST_USERS.teacher);
    
    // Step 2: Navigate
    await navigateTo(page, 'teacherClassrooms');
    
    // Step 3: Perform action
    // ...
    
    // Step 4: Verify
    // ...
  });
});

/**
 * Cross-user workflow example (Teacher → Student interaction)
 */
test.describe('Cross-User: [Name]', () => {
  test('teacher action followed by student action', async ({ browser }) => {
    // Create two separate browser contexts
    const teacherContext = await browser.newContext();
    const studentContext = await browser.newContext();
    
    const teacherPage = await teacherContext.newPage();
    const studentPage = await studentContext.newPage();
    
    try {
      // Teacher does something
      const teacherAuth = createAuthHelper(teacherPage);
      await teacherAuth.login(TEST_USERS.teacher);
      // ... teacher actions
      
      // Student sees the result
      const studentAuth = createAuthHelper(studentPage);
      await studentAuth.login(TEST_USERS.student);
      // ... student actions
      
      // Verify interaction
      // ...
    } finally {
      await teacherContext.close();
      await studentContext.close();
    }
  });
});

/**
 * Data-driven test example
 */
test.describe('Data-Driven: [Name]', () => {
  const testCases = [
    { user: TEST_USERS.student, expected: 'student view' },
    { user: TEST_USERS.teacher, expected: 'teacher view' },
    { user: TEST_USERS.admin, expected: 'admin view' },
  ];

  for (const { user, expected } of testCases) {
    test(`shows ${expected} for ${user.type}`, async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(user);
      
      // ... test logic
    });
  }
});

/**
 * Mobile responsiveness test example
 */
test.describe('Mobile: [Name]', () => {
  test.use({ viewport: { width: 375, height: 667 } }); // iPhone SE size

  test('works on mobile devices', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Test mobile-specific interactions
    // ...
  });
});

/**
 * Tips for writing good scenarios:
 *
 * 1. Use descriptive test names that explain what is being tested
 * 2. Group related tests with describe blocks
 * 3. Use the helper functions for common operations
 * 4. Add data-testid attributes to your components for reliable selectors
 * 5. Clean up any created data in afterEach if needed
 * 6. Use unique names/titles to avoid conflicts between test runs
 * 7. Test both happy paths and error cases
 */
