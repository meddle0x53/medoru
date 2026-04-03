/**
 * Classroom Lesson Notification Scenario
 *
 * End-to-end test covering:
 * 1. Teacher creates a classroom
 * 2. Student applies to classroom with invite code
 * 3. Teacher approves the student
 * 4. Teacher creates a lesson and publishes it to the classroom
 * 5. Student receives a notification for the new lesson
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

const TEST_DATA = {
  classroomName: `Notify Classroom ${Date.now()}`,
  classroomDescription: 'Classroom for notification testing',
  lessonName: `Notify Lesson ${Date.now()}`,
};

test.describe('Classroom Lesson Notification Flow', () => {
  test.describe.configure({ mode: 'serial' });

  let inviteCode: string;
  let classroomId: string;

  test('teacher creates a classroom', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.teacher);

    await navigateTo(page, 'teacherClassrooms');
    await expect(page.locator('h1')).toContainText('Classrooms');

    const createButton = page.locator('a[href="/teacher/classrooms/new"]').first();
    await expect(createButton).toBeVisible({ timeout: 10000 });
    await createButton.click();

    await page.waitForSelector('#classroom-form', { timeout: 10000 });
    await expect(page.locator('h1')).toContainText('Create Classroom');

    await page.fill('input[name="classroom[name]"]', TEST_DATA.classroomName);
    await page.fill('textarea[name="classroom[description]"]', TEST_DATA.classroomDescription);
    await page.click('button[type="submit"]:has-text("Create Classroom")');

    await page.waitForURL(/.*teacher\/classrooms\/.+/, { timeout: 15000 });
    await expect(page.locator('h1')).toContainText(TEST_DATA.classroomName, { timeout: 10000 });

    const url = page.url();
    classroomId = new URL(url).pathname.split('/').pop() || '';
    expect(classroomId).toBeTruthy();
    expect(classroomId).not.toBe('new');

    const inviteCodeElement = page.locator('.font-mono').first();
    await expect(inviteCodeElement).toBeVisible({ timeout: 10000 });
    inviteCode = (await inviteCodeElement.textContent() || '').trim();

    expect(inviteCode).toBeTruthy();
    console.log(`✅ Classroom created: ${TEST_DATA.classroomName}, id: ${classroomId}, code: ${inviteCode}`);
  });

  test('student applies to classroom with invite code', async ({ page }) => {
    test.skip(!inviteCode, 'Invite code not available');

    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);

    await navigateTo(page, 'classroomJoin');
    await expect(page.locator('h1')).toContainText(/Join Classroom/i, { timeout: 10000 });

    // Wait for LiveView to fully connect before interacting
    await page.waitForSelector('.phx-connected', { timeout: 10000 });
    await page.waitForTimeout(1500); // wait for LiveView remount/crash to settle

    const codeInput = page.locator('input[name="invite_code"]').first();
    await expect(codeInput).toBeVisible({ timeout: 10000 });
    await codeInput.fill(inviteCode);
    
    // Dispatch change event to trigger LiveView phx-change on the form
    await codeInput.evaluate((el) => {
      el.dispatchEvent(new Event('change', { bubbles: true }));
    });

    // Wait for the classroom preview to appear
    await expect(page.locator('text=Classroom Found!')).toBeVisible({ timeout: 10000 });

    const joinButton = page.locator('button[type="submit"]:has-text("Apply to Join")');
    await expect(joinButton).toBeVisible({ timeout: 10000 });
    await joinButton.click();

    await page.waitForURL('/classrooms', { timeout: 15000 });
    const bodyText = await page.locator('body').textContent() || '';
    expect(bodyText).toMatch(/applied|pending|success|request/i);

    console.log(`✅ Student applied to classroom`);
  });

  test('teacher approves the student', async ({ page }) => {
    test.skip(!classroomId, 'Classroom ID not available');

    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.teacher);

    await navigateTo(page, `teacher/classrooms/${classroomId}` as any);
    await expect(page.locator('h1')).toContainText(TEST_DATA.classroomName, { timeout: 10000 });
    await page.waitForSelector('.phx-connected', { timeout: 10000 });
    await page.waitForTimeout(1500); // wait for LiveView remount/crash to settle

    const studentsTab = page.locator('button[phx-value-tab="students"]').first();
    await expect(studentsTab).toBeVisible({ timeout: 10000 });
    await studentsTab.click();

    // Wait for the pending applications section
    const pendingCard = page.locator('text=Pending Applications').first();
    await expect(pendingCard).toBeVisible({ timeout: 10000 });

    const approveButton = page.locator('button:has-text("Approve")').first();
    await expect(approveButton).toBeVisible({ timeout: 10000 });
    await approveButton.click();
    await expect(page.locator('text=/approved|success/i').first()).toBeVisible({ timeout: 10000 });
    console.log(`✅ Teacher approved student`);
  });

  test('teacher creates a custom lesson and publishes it to the classroom', async ({ page }) => {
    test.skip(!classroomId, 'Classroom ID not available');

    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.teacher);

    // Create lesson
    await navigateTo(page, 'teacherCustomLessons');
    await expect(page.locator('h1')).toContainText(/Custom Lessons|Lessons/i, { timeout: 10000 });

    const createButton = page.locator('a[href="/teacher/custom-lessons/new"]').first();
    await expect(createButton).toBeVisible({ timeout: 10000 });
    await createButton.click();

    await page.waitForSelector('#lesson-form', { timeout: 10000 });
    await expect(page.locator('h1')).toContainText('Create New Lesson');

    await page.fill('input[name="custom_lesson[title]"]', TEST_DATA.lessonName);
    await page.fill('textarea[name="custom_lesson[description]"]', 'QA lesson for notification test');
    await page.locator('label:has-text("N5")').click();
    await page.click('button[type="submit"]:has-text("Create & Add Words")');

    await page.waitForURL(/.*teacher\/custom-lessons\/.+\/edit/, { timeout: 15000 });

    // Add a word so we can publish
    const searchInput = page.locator('input[name="query"]').first();
    await expect(searchInput).toBeVisible({ timeout: 10000 });
    await searchInput.click();
    await searchInput.fill('日本');
    await page.waitForTimeout(500);

    // Wait for search results to appear
    const searchResult = page.locator('text=日本').first();
    await expect(searchResult).toBeVisible({ timeout: 10000 });

    const addButton = page.locator('button[phx-click="add_word"]').first();
    await expect(addButton).toBeVisible({ timeout: 5000 });
    await addButton.click();

    // Wait for word to be added (word count updates)
    await expect(page.locator('text=/1 word|words/i').first()).toBeVisible({ timeout: 10000 });

    // Publish lesson
    const publishButton = page.locator('button:has-text("Publish")').first();
    await expect(publishButton).toBeVisible({ timeout: 10000 });
    await publishButton.click();

    await page.waitForURL(/.*publish/, { timeout: 10000 });

    // Select classroom
    const classroomCheckbox = page.locator(`label:has-text("${TEST_DATA.classroomName}") input[type="checkbox"]`).first();
    if (await classroomCheckbox.isVisible({ timeout: 5000 }).catch(() => false)) {
      await classroomCheckbox.check();
    }

    await page.click('button:has-text("Publish")');
    await expect(page.locator('text=/published|success/i').first()).toBeVisible({ timeout: 10000 });

    console.log(`✅ Lesson created and published: ${TEST_DATA.lessonName}`);
  });

  test('student sees notification for the new lesson', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);

    // Navigate to the notifications page
    await navigateTo(page, 'notifications');
    await expect(page.locator('h1')).toContainText('Notifications', { timeout: 10000 });

    // Wait a moment for any background notification creation to complete
    await page.waitForTimeout(1000);

    // Look for the notification about the new lesson
    const notification = page.locator(`text=/New Lesson in ${TEST_DATA.classroomName}/i`).first();
    await expect(notification).toBeVisible({ timeout: 10000 });

    // Also verify the lesson title is mentioned and a link is present
    await expect(page.locator(`text=${TEST_DATA.lessonName}`).first()).toBeVisible({ timeout: 10000 });
    await expect(page.locator('a:has-text("Start Lesson")').first()).toBeVisible({ timeout: 10000 });

    console.log(`✅ Student received notification for published lesson`);
  });
});
