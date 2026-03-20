/**
 * Authentication Setup
 *
 * This file runs before other tests to set up authenticated sessions.
 * It logs in as a default student user and saves the storage state.
 */

import { test as setup, expect } from '@playwright/test';
import { authenticateAndSaveState, waitForServer } from '../helpers/auth';
import { TEST_USERS } from '../fixtures/users';

const authFile = 'playwright/.auth/user.json';

setup('authenticate as default student', async ({ request }) => {
  // Wait for QA server to be ready
  await waitForServer(request);

  // Authenticate as the default student user
  await authenticateAndSaveState(request, TEST_USERS.student, authFile);

  console.log('✅ Authentication setup complete');
});

setup('authenticate as teacher', async ({ request }) => {
  await waitForServer(request);
  await authenticateAndSaveState(request, TEST_USERS.teacher, 'playwright/.auth/teacher.json');
  console.log('✅ Teacher authentication setup complete');
});

setup('authenticate as admin', async ({ request }) => {
  await waitForServer(request);
  await authenticateAndSaveState(request, TEST_USERS.admin, 'playwright/.auth/admin.json');
  console.log('✅ Admin authentication setup complete');
});
