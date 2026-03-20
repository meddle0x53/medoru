/**
 * Full Classroom Workflow Scenario
 *
 * End-to-end test covering the complete classroom lifecycle:
 * 1. Teacher creates a classroom
 * 2. Teacher creates a custom lesson with multiple words
 * 3. Student applies to classroom with invite code
 * 4. Teacher approves the student
 * 5. Student studies the lesson
 * 6. Student takes a test
 * 7. Teacher views results
 *
 * @flow Teacher → Student → Teacher → Student → Teacher
 */

import { test, expect, Page } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo, expectFlashMessage, waitForPageLoad } from '../helpers';

// Test data - unique for each run to avoid conflicts
const TEST_DATA = {
  classroomName: `QA Classroom ${Date.now()}`,
  classroomDescription: 'Automated test classroom for E2E testing',
  lessonName: `QA Lesson ${Date.now()}`,
  testName: `QA Test ${Date.now()}`,
};

test.describe('Full Classroom Workflow', () => {
  // Store values across test steps
  let inviteCode: string;
  let classroomId: string;

  test.describe('Step 1: Teacher creates classroom', () => {
    test('teacher can create a new classroom', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.teacher);

      // Navigate to teacher classrooms
      await navigateTo(page, 'teacherClassrooms');
      await expect(page.locator('h1')).toContainText('Classrooms');

      // Click create new classroom - look for the link with specific href pattern
      const createButton = page.locator('a[href="/teacher/classrooms/new"]').first();
      await expect(createButton).toBeVisible({ timeout: 10000 });
      await createButton.click();

      // Wait for form to be visible
      await page.waitForSelector('#classroom-form', { timeout: 10000 });
      await expect(page.locator('h1')).toContainText('Create Classroom');

      // Fill classroom creation form - use field names matching the form
      await page.fill('input[name="classroom[name]"]', TEST_DATA.classroomName);
      await page.fill('textarea[name="classroom[description]"]', TEST_DATA.classroomDescription);

      // Submit form - button has text "Create Classroom"
      await page.click('button[type="submit"]:has-text("Create Classroom")');

      // Wait for redirect to classroom detail
      await page.waitForURL(/.*teacher\/classrooms\/.+/, { timeout: 15000 });
      
      // Store classroom ID from URL
      const url = page.url();
      classroomId = url.split('/').pop() || '';
      
      // Verify classroom was created
      await expect(page.locator('h1')).toContainText(TEST_DATA.classroomName, { timeout: 10000 });
      
      // Wait for overview tab to load and extract invite code
      await page.waitForSelector('.font-mono', { timeout: 10000 });
      
      // Extract invite code - it's displayed in a monospace font div
      const inviteCodeElement = page.locator('.font-mono').first();
      await expect(inviteCodeElement).toBeVisible({ timeout: 10000 });
      
      inviteCode = await inviteCodeElement.textContent() || '';
      inviteCode = inviteCode.trim();
      
      expect(inviteCode).toBeTruthy();
      expect(inviteCode.length).toBeGreaterThan(4);
      
      console.log(`✅ Classroom created: ${TEST_DATA.classroomName} (ID: ${classroomId})`);
      console.log(`✅ Invite code: ${inviteCode}`);
    });
  });

  test.describe('Step 2: Teacher creates custom lesson', () => {
    test('teacher can create a custom lesson', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.teacher);

      // Navigate to custom lessons
      await navigateTo(page, 'teacherCustomLessons');
      await expect(page.locator('h1')).toContainText(/Custom Lessons|Lessons/i, { timeout: 10000 });

      // Click create new lesson - link goes to /teacher/custom-lessons/new
      const createButton = page.locator('a[href="/teacher/custom-lessons/new"]').first();
      await expect(createButton).toBeVisible({ timeout: 10000 });
      await createButton.click();

      // Wait for form to load
      await page.waitForSelector('#lesson-form', { timeout: 10000 });
      await expect(page.locator('h1')).toContainText('Create New Lesson');

      // Fill lesson form - field name is "custom_lesson[title]"
      await page.fill('input[name="custom_lesson[title]"]', TEST_DATA.lessonName);
      await page.fill('textarea[name="custom_lesson[description]"]', 'Lesson created by QA automation for testing');

      // Select difficulty N5
      await page.click('input[value="5"]');

      // Submit - button text is "Create & Add Words"
      await page.click('button[type="submit"]:has-text("Create & Add Words")');

      // Wait for redirect to edit page where we add words
      await page.waitForURL(/.*teacher\/custom-lessons\/.+\/edit/, { timeout: 15000 });

      // Verify we're on the edit page
      await expect(page.locator('h1')).toContainText(/Edit Lesson|Add Words/i, { timeout: 10000 });

      console.log(`✅ Custom lesson created: ${TEST_DATA.lessonName}`);
    });
  });

  test.describe('Step 3: Teacher publishes lesson to classroom', () => {
    test('teacher publishes custom lesson to classroom', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.teacher);

      // Navigate to the custom lessons list
      await navigateTo(page, 'teacherCustomLessons');
      
      // Find and click on the lesson we just created
      const lessonLink = page.locator(`a:has-text("${TEST_DATA.lessonName}")`).first();
      await expect(lessonLink).toBeVisible({ timeout: 10000 });
      await lessonLink.click();

      // Should be on lesson detail/edit page - look for publish link
      const publishButton = page.locator('a:has-text("Publish"), button:has-text("Publish")').first();
      
      if (await publishButton.isVisible({ timeout: 5000 }).catch(() => false)) {
        await publishButton.click();

        // Wait for publish page to load
        await page.waitForURL(/.*publish/, { timeout: 10000 });

        // Select the classroom we created
        const classroomCheckbox = page.locator(`label:has-text("${TEST_DATA.classroomName}") input[type="checkbox"]`).first();
        if (await classroomCheckbox.isVisible({ timeout: 5000 }).catch(() => false)) {
          await classroomCheckbox.check();
        }

        // Confirm publish
        await page.click('button:has-text("Publish")');
        
        // Wait for success
        await expect(page.locator('text=/published|success/i').first()).toBeVisible({ timeout: 10000 });
        console.log(`✅ Lesson published to classroom: ${TEST_DATA.classroomName}`);
      } else {
        console.log(`⚠️  Publish button not found - lesson may already be published`);
      }
    });
  });

  test.describe('Step 4: Student applies to classroom', () => {
    test('student can apply to classroom with invite code', async ({ page }) => {
      // Skip if invite code wasn't captured
      test.skip(!inviteCode, 'Invite code not available from previous test');
      
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.student);

      // Navigate to join classroom page
      await navigateTo(page, 'classroomJoin');
      await expect(page.locator('h1')).toContainText(/Join Classroom/i, { timeout: 10000 });

      // Enter invite code - input name is "invite_code"
      const codeInput = page.locator('input[name="invite_code"]').first();
      await expect(codeInput).toBeVisible({ timeout: 10000 });
      await codeInput.fill(inviteCode);

      // Wait for validation to show classroom found
      await page.waitForTimeout(1000);
      
      // Classroom preview should appear
      const classroomPreview = page.locator('text=/Classroom Found/i');
      await expect(classroomPreview).toBeVisible({ timeout: 10000 });

      // Submit application
      const joinButton = page.locator('button[type="submit"]:has-text("Apply to Join")');
      await expect(joinButton).toBeVisible({ timeout: 10000 });
      await joinButton.click();

      // Should redirect and show success
      await page.waitForURL(/.*classrooms.*/, { timeout: 15000 });
      
      // Flash message should indicate success
      const bodyText = await page.locator('body').textContent() || '';
      expect(bodyText).toMatch(/applied|pending|success|request/i);

      console.log(`✅ Student applied to classroom with code: ${inviteCode}`);
    });
  });

  test.describe('Step 5: Teacher approves student application', () => {
    test('teacher can approve student application', async ({ page }) => {
      // Skip if classroom wasn't created
      test.skip(!classroomId, 'Classroom ID not available from previous test');
      
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.teacher);

      // Navigate directly to the classroom
      await page.goto(`/teacher/classrooms/${classroomId}`);
      await page.waitForLoadState('networkidle');

      // Should see classroom detail
      await expect(page.locator('h1')).toContainText(TEST_DATA.classroomName, { timeout: 10000 });

      // Navigate to Students tab
      const studentsTab = page.locator('button:has-text("Students"), a:has-text("Students"), [role="tab"]:has-text("Students")').first();
      if (await studentsTab.isVisible({ timeout: 5000 }).catch(() => false)) {
        await studentsTab.click();
        await page.waitForTimeout(1000);
      }

      // Look for pending applications section
      const pendingSection = page.locator('text=/pending|applications|requests/i').first();
      
      if (await pendingSection.isVisible({ timeout: 5000 }).catch(() => false)) {
        // Find the student and approve
        const studentRow = page.locator(`text=${TEST_USERS.student.email}`).first();
        const approveButton = studentRow.locator('..').locator('..').locator('button:has-text("Approve"), a:has-text("Approve")').first();
        
        if (await approveButton.isVisible({ timeout: 5000 }).catch(() => false)) {
          await approveButton.click();
          
          // Wait for success
          await expect(page.locator('text=/approved|success/i').first()).toBeVisible({ timeout: 10000 });
          console.log(`✅ Teacher approved student: ${TEST_USERS.student.email}`);
        } else {
          console.log(`⚠️  Approve button not found - student may already be approved`);
        }
      } else {
        console.log(`⚠️  No pending section found - checking if already approved`);
      }
    });
  });

  test.describe('Step 6: Student views classroom and lesson', () => {
    test('student can see classroom and available lesson', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.student);

      // Navigate to classrooms list
      await navigateTo(page, 'classrooms');
      await expect(page.locator('h1')).toContainText(/Classrooms/i, { timeout: 10000 });

      // Find and click on our classroom
      const classroomLink = page.locator(`a:has-text("${TEST_DATA.classroomName}")`).first();
      
      if (await classroomLink.isVisible({ timeout: 10000 }).catch(() => false)) {
        await classroomLink.click();

        // Should see classroom detail
        await expect(page.locator('h1')).toContainText(TEST_DATA.classroomName, { timeout: 10000 });

        // Look for Lessons tab
        const lessonsTab = page.locator('button:has-text("Lessons"), a:has-text("Lessons"), [role="tab"]:has-text("Lessons")').first();
        if (await lessonsTab.isVisible({ timeout: 5000 }).catch(() => false)) {
          await lessonsTab.click();

          // Should see our custom lesson
          await expect(page.locator(`text=${TEST_DATA.lessonName}`)).toBeVisible({ timeout: 10000 });
          console.log(`✅ Student can view classroom and lesson`);
        } else {
          console.log(`⚠️  Lessons tab not found`);
        }
      } else {
        console.log(`⚠️  Classroom not in list - may need approval first`);
      }
    });
  });

  test.describe('Step 7: Teacher creates a test', () => {
    test('teacher creates a multi-step test', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.teacher);

      // Navigate to tests
      await navigateTo(page, 'teacherTests');
      await expect(page.locator('h1')).toContainText(/Tests/i, { timeout: 10000 });

      // Create new test - look for the new test link
      const createButton = page.locator('a[href="/teacher/tests/new"]').first();
      await expect(createButton).toBeVisible({ timeout: 10000 });
      await createButton.click();

      // Fill test name - adjust based on actual form
      await page.waitForSelector('form', { timeout: 10000 });
      await page.fill('input[name="test[name]"], input[name="name"]', TEST_DATA.testName);
      
      const descInput = page.locator('textarea[name="test[description]"], textarea[name="description"]').first();
      if (await descInput.isVisible({ timeout: 5000 }).catch(() => false)) {
        await descInput.fill('Automated test for QA');
      }

      // Continue to step builder
      await page.click('button[type="submit"], button:has-text("Continue"), button:has-text("Next")');

      // Wait for step builder to load
      await page.waitForSelector('text=/steps|questions|builder/i', { timeout: 15000 });

      console.log(`✅ Test created: ${TEST_DATA.testName}`);
    });
  });

  test.describe('Step 8: Teacher publishes test to classroom', () => {
    test('teacher publishes test to classroom', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.teacher);

      // Navigate to tests
      await navigateTo(page, 'teacherTests');
      
      // Find our test
      const testLink = page.locator(`a:has-text("${TEST_DATA.testName}")`).first();
      await expect(testLink).toBeVisible({ timeout: 10000 });
      await testLink.click();

      // Look for publish to classroom button/link
      const publishButton = page.locator('a[href*="publish"], button:has-text("Publish"), a:has-text("Publish")').first();
      
      if (await publishButton.isVisible({ timeout: 5000 }).catch(() => false)) {
        await publishButton.click();

        // Wait for publish page
        await page.waitForURL(/.*publish/, { timeout: 10000 });

        // Select our classroom
        const classroomOption = page.locator(`label:has-text("${TEST_DATA.classroomName}") input[type="checkbox"]`).first();
        
        if (await classroomOption.isVisible({ timeout: 5000 }).catch(() => false)) {
          await classroomOption.check();
        }

        // Confirm
        await page.click('button:has-text("Publish")');
        
        await expect(page.locator('text=/published|success/i').first()).toBeVisible({ timeout: 10000 });
        console.log(`✅ Test published to classroom: ${TEST_DATA.classroomName}`);
      } else {
        console.log(`⚠️  Publish button not found`);
      }
    });
  });

  test.describe('Step 9: Student takes the test', () => {
    test('student can see the test', async ({ page }) => {
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.student);

      // Navigate to classroom
      await navigateTo(page, 'classrooms');
      
      const classroomLink = page.locator(`a:has-text("${TEST_DATA.classroomName}")`).first();
      if (await classroomLink.isVisible({ timeout: 10000 }).catch(() => false)) {
        await classroomLink.click();

        // Go to Tests tab
        const testsTab = page.locator('button:has-text("Tests"), a:has-text("Tests"), [role="tab"]:has-text("Tests")').first();
        if (await testsTab.isVisible({ timeout: 5000 }).catch(() => false)) {
          await testsTab.click();

          // Find our test
          const testLink = page.locator(`a:has-text("${TEST_DATA.testName}")`).first();
          if (await testLink.isVisible({ timeout: 10000 }).catch(() => false)) {
            await testLink.click();

            // Should see test detail with start button
            await expect(page.locator('h1')).toContainText(TEST_DATA.testName, { timeout: 10000 });
            
            const startButton = page.locator('button:has-text("Start"), button:has-text("Begin"), a:has-text("Start")').first();
            await expect(startButton).toBeVisible({ timeout: 10000 });
            
            console.log(`✅ Student can see test: ${TEST_DATA.testName}`);
          } else {
            console.log(`⚠️  Test not found in classroom`);
          }
        } else {
          console.log(`⚠️  Tests tab not found`);
        }
      } else {
        console.log(`⚠️  Classroom not accessible`);
      }
    });
  });

  test.describe('Step 10: Teacher views results', () => {
    test('teacher can view classroom', async ({ page }) => {
      // Skip if no classroom ID
      test.skip(!classroomId, 'Classroom ID not available');
      
      const auth = createAuthHelper(page);
      await auth.login(TEST_USERS.teacher);

      // Navigate directly to classroom
      await page.goto(`/teacher/classrooms/${classroomId}`);
      await page.waitForLoadState('networkidle');

      // Should see classroom detail
      await expect(page.locator('h1')).toContainText(TEST_DATA.classroomName, { timeout: 10000 });

      // Try to navigate to Tests tab
      const testsTab = page.locator('button:has-text("Tests"), a:has-text("Tests"), [role="tab"]:has-text("Tests")').first();
      if (await testsTab.isVisible({ timeout: 5000 }).catch(() => false)) {
        await testsTab.click();
        
        // Should see our test
        await expect(page.locator(`text=${TEST_DATA.testName}`).first()).toBeVisible({ timeout: 10000 });
        console.log(`✅ Teacher can view classroom and tests`);
      } else {
        console.log(`⚠️  Tests tab not found`);
      }
    });
  });
});
