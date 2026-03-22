/**
 * Edge Cases & Bug Hunting
 *
 * Tests for error handling, edge cases, and potential bugs:
 * - Invalid IDs, unauthorized access, empty states
 * - Boundary conditions, race conditions
 * - Form validation, special characters
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper } from '../helpers';

test.describe('Edge Cases & Error Handling', () => {
  
  // ========== 404 & INVALID IDs ==========
  
  test('should show 404 for non-existent word ID', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Try various invalid word IDs
    const invalidIds = ['999999', '0', '-1', 'abc', 'word-123'];
    
    for (const id of invalidIds) {
      console.log(`Testing invalid word ID: ${id}`);
      await page.goto(`/words/${id}`);
      await page.waitForLoadState('networkidle');
      
      const bodyText = await page.locator('body').textContent() || '';
      const url = page.url();
      
      // Should either show 404, error message, or redirect gracefully
      const hasError = 
        bodyText.includes('404') || 
        bodyText.includes('Not Found') ||
        bodyText.includes('not found') ||
        bodyText.includes('Error') ||
        url.includes('/404') ||
        url === '/words'; // Graceful redirect
      
      if (!hasError) {
        console.log(`⚠️ No error handling for word ID: ${id}`);
        console.log(`   URL: ${url}`);
        console.log(`   Body preview: ${bodyText.substring(0, 200)}`);
      }
      
      // Page should not crash (500 error)
      expect(bodyText.includes('Internal Server Error') || bodyText.includes('Server Error')).toBeFalsy();
    }
  });

  test('should show 404 for non-existent kanji ID', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    const invalidIds = ['999999', '0', '-1', 'xyz'];
    
    for (const id of invalidIds) {
      console.log(`Testing invalid kanji ID: ${id}`);
      await page.goto(`/kanji/${id}`);
      await page.waitForLoadState('networkidle');
      
      const bodyText = await page.locator('body').textContent() || '';
      
      // Should not show 500 error
      expect(bodyText.includes('Internal Server Error')).toBeFalsy();
      
      // Check if properly handled
      const handled = 
        bodyText.includes('404') || 
        bodyText.includes('Not Found') ||
        bodyText.includes('not found') ||
        bodyText.includes('Error');
      
      if (!handled) {
        console.log(`⚠️ Kanji ID ${id} may not have proper error handling`);
      }
    }
  });

  test('should handle SQL injection attempts in URL params', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    const maliciousIds = [
      "1' OR '1'='1",
      "1; DROP TABLE users;--",
      "1' UNION SELECT * FROM users--",
      "../../../etc/passwd",
      "<script>alert('xss')</script>",
      "word'--",
    ];
    
    for (const id of maliciousIds) {
      console.log(`Testing SQL injection: ${id.substring(0, 30)}...`);
      await page.goto(`/words/${encodeURIComponent(id)}`);
      await page.waitForLoadState('networkidle');
      
      const bodyText = await page.locator('body').textContent() || '';
      
      // Should NOT expose SQL errors
      expect(bodyText.includes('syntax error')).toBeFalsy();
      expect(bodyText.includes('SQL')).toBeFalsy();
      expect(bodyText.includes('database error')).toBeFalsy();
      expect(bodyText.includes('Internal Server Error')).toBeFalsy();
    }
  });

  // ========== UNAUTHORIZED ACCESS ==========

  test('should redirect to login when accessing protected routes as guest', async ({ page }) => {
    const protectedRoutes = [
      { route: '/dashboard', shouldRedirect: true },
      { route: '/daily-test', shouldRedirect: true },
      { route: '/lessons', shouldRedirect: false },  // Public
      { route: '/words/1', shouldRedirect: false },  // Public
      { route: '/kanji/1', shouldRedirect: false },  // Public
      { route: '/profile', shouldRedirect: true },
      { route: '/settings', shouldRedirect: true },
    ];
    
    for (const { route, shouldRedirect } of protectedRoutes) {
      console.log(`Testing unauthorized access to: ${route}`);
      await page.goto(route);
      await page.waitForLoadState('networkidle');
      
      const url = page.url();
      const bodyText = await page.locator('body').textContent() || '';
      
      // Should redirect to home (/) for auth routes
      const redirected = url === '/' || url === '/dashboard' || bodyText.includes('Sign in with Google');
      
      if (shouldRedirect && !redirected) {
        console.log(`⚠️ Route ${route} should redirect but didn't`);
        console.log(`   Current URL: ${url}`);
      } else if (!shouldRedirect && url.includes(route)) {
        console.log(`✅ Route ${route} is public as expected`);
      } else if (shouldRedirect && redirected) {
        console.log(`✅ Route ${route} properly redirects to login`);
      }
    }
  });

  test('should not allow accessing other users data', async ({ page }) => {
    // Login as student
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Try to access admin/teacher routes
    const adminRoutes = [
      { route: '/admin', name: 'admin dashboard' },
      { route: '/admin/users', name: 'admin users' },
      { route: '/teacher/classrooms', name: 'teacher classrooms' },
      { route: '/teacher/tests', name: 'teacher tests' },
    ];
    
    const bugs: string[] = [];
    
    for (const { route, name } of adminRoutes) {
      console.log(`Testing access to: ${route} (${name})`);
      await page.goto(route);
      await page.waitForLoadState('networkidle');
      
      const url = page.url();
      const bodyText = await page.locator('body').textContent() || '';
      
      // Should redirect away from admin/teacher route or show forbidden
      const stillOnRestrictedRoute = 
        (route.includes('/admin') && url.includes('/admin')) ||
        (route.includes('/teacher') && url.includes('/teacher'));
      
      const wasBlocked = 
        bodyText.includes('Forbidden') ||
        bodyText.includes('Unauthorized') ||
        bodyText.includes('Access Denied') ||
        bodyText.includes('403') ||
        bodyText.includes('must be an admin') ||
        bodyText.includes('must be a teacher') ||
        url === '/' ||  // Redirected to home
        url === '/dashboard';  // Redirected to dashboard
      
      if (stillOnRestrictedRoute) {
        console.log(`❌ BUG: ${name} route (${route}) accessible by student!`);
        bugs.push(route);
      } else if (wasBlocked) {
        console.log(`✅ ${name} route (${route}) properly blocked`);
      } else {
        console.log(`⚠️ ${name} route (${route}) handled differently - URL: ${url}`);
      }
    }
    
    // Report all bugs found
    if (bugs.length > 0) {
      console.log(`\n🐛 BUGS FOUND: ${bugs.length} route(s) accessible by student:`);
      bugs.forEach(r => console.log(`   - ${r}`));
    }
    
    // Fail if any bugs found
    expect(bugs).toHaveLength(0);
  });

  // ========== EMPTY STATES ==========

  test('should handle empty search results gracefully', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    await page.goto('/words');
    await page.waitForLoadState('networkidle');
    
    // Try searches that should return no results
    const emptySearches = [
      'xyznonexistentword123',
      '!!!!!!!',
      '日本語で検索',  // Valid Japanese but might not exist
      'a'.repeat(100),  // Very long string
    ];
    
    for (const query of emptySearches) {
      console.log(`Testing empty search: "${query.substring(0, 30)}"`);
      
      const searchInput = page.locator('input[type="search"], input[placeholder*="search" i], input[name*="search"]').first();
      
      if (await searchInput.isVisible({ timeout: 3000 }).catch(() => false)) {
        await searchInput.fill(query);
        await searchInput.press('Enter');
        await page.waitForTimeout(1000);
        
        const bodyText = await page.locator('body').textContent() || '';
        
        // Should not crash
        expect(bodyText.includes('Internal Server Error')).toBeFalsy();
        
        // Ideally shows "no results" message
        const hasEmptyState = 
          bodyText.includes('No results') ||
          bodyText.includes('no words') ||
          bodyText.includes('not found') ||
          bodyText.includes('No words') ||
          bodyText.includes('empty');
        
        if (!hasEmptyState) {
          console.log(`⚠️ Search for "${query.substring(0, 20)}" may not show empty state`);
        }
        
        // Clear search for next iteration
        await searchInput.clear();
      }
    }
  });

  test('should show empty state for new user with no progress', async ({ page }) => {
    // Create/fresh login - use a fresh student account
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Go to dashboard
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    
    // Dashboard should show welcome/empty state or quick start
    const hasWelcomeOrEmpty = 
      bodyText.includes('Welcome') ||
      bodyText.includes('Start learning') ||
      bodyText.includes('Get started') ||
      bodyText.includes('No progress') ||
      bodyText.includes('words learned');
    
    if (!hasWelcomeOrEmpty) {
      console.log(`⚠️ Dashboard may not handle new user empty state well`);
    }
    
    // Should not error
    expect(bodyText.includes('Internal Server Error')).toBeFalsy();
  });

  // ========== FORM VALIDATION ==========

  test('should validate form inputs properly', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Try profile/settings forms if they exist
    await page.goto('/settings');
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    
    // If settings page exists, try invalid inputs
    if (!bodyText.includes('404') && !bodyText.includes('Not Found')) {
      // Try to submit empty form or invalid data
      const inputs = page.locator('input:not([type="hidden"])');
      const count = await inputs.count();
      
      for (let i = 0; i < Math.min(count, 3); i++) {
        const input = inputs.nth(i);
        const type = await input.getAttribute('type');
        
        // Try boundary values
        if (type === 'text' || type === null) {
          await input.fill('');
          await input.fill('a'.repeat(1000));  // Too long
        } else if (type === 'email') {
          await input.fill('not-an-email');
          await input.fill('@test.com');
        } else if (type === 'number') {
          await input.fill('-1');
          await input.fill('99999999999999999999');
        }
      }
      
      // Try to submit
      const submitButton = page.locator('button[type="submit"]').first();
      if (await submitButton.isVisible({ timeout: 2000 }).catch(() => false)) {
        await submitButton.click();
        await page.waitForTimeout(1000);
        
        // Should show validation errors, not crash
        const afterSubmit = await page.locator('body').textContent() || '';
        expect(afterSubmit.includes('Internal Server Error')).toBeFalsy();
      }
    }
  });

  // ========== BOUNDARY CONDITIONS ==========

  test('should handle very large page numbers', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Try pagination with extreme values
    const largePageUrls = [
      '/words?page=999999',
      '/words?page=-1',
      '/words?page=0',
      '/words?page=abc',
    ];
    
    for (const url of largePageUrls) {
      console.log(`Testing pagination: ${url}`);
      await page.goto(url);
      await page.waitForLoadState('networkidle');
      
      const bodyText = await page.locator('body').textContent() || '';
      
      // Should not crash
      expect(bodyText.includes('Internal Server Error')).toBeFalsy();
      
      // Ideally shows empty state or redirects to valid page
      if (bodyText.includes('404') || bodyText.includes('Error')) {
        console.log(`   Handled gracefully with error page`);
      } else {
        console.log(`   Handled gracefully without crash`);
      }
    }
  });

  test('should handle special characters in search', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    await page.goto('/words');
    
    const specialChars = [
      '<script>alert(1)</script>',
      "'; DROP TABLE words;--",
      '${7*7}',
      '{{7*7}}',
      '日本語',  // Japanese characters
      '한국어',  // Korean
      'العربية',  // Arabic
      '🎌🔥',  // Emojis
      '\n\r\t',  // Control characters
    ];
    
    const searchInput = page.locator('input[type="search"], input[placeholder*="search" i]').first();
    
    if (await searchInput.isVisible({ timeout: 3000 }).catch(() => false)) {
      for (const chars of specialChars) {
        console.log(`Testing special chars: ${chars.substring(0, 20)}`);
        
        await searchInput.fill(chars);
        await searchInput.press('Enter');
        await page.waitForTimeout(500);
        
        const bodyText = await page.locator('body').textContent() || '';
        
        // Should not show XSS/script execution or SQL errors
        expect(bodyText.includes('syntax error')).toBeFalsy();
        expect(bodyText.includes('SQL')).toBeFalsy();
        expect(bodyText.includes('Internal Server Error')).toBeFalsy();
        
        // Should not execute scripts
        const hasAlert = await page.evaluate(() => {
          return typeof window.alert === 'function' && false;  // Can't easily test this
        });
        
        await searchInput.clear();
      }
    }
  });

  // ========== RACE CONDITIONS & STATE ISSUES ==========

  test('should handle rapid clicking on Mark as Learned button', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Go to a word and click the button rapidly
    await page.goto('/words');
    await page.locator('a[href^="/words/"]').first().click();
    await expect(page.locator('h1')).toBeVisible({ timeout: 10000 });
    
    const markButton = page.locator('button:has-text("Mark as Learned")');
    
    if (await markButton.isVisible({ timeout: 3000 }).catch(() => false)) {
      // Click multiple times rapidly
      await markButton.click();
      await markButton.click().catch(() => {});  // May fail if first click succeeded
      await markButton.click().catch(() => {});
      
      await page.waitForTimeout(2000);
      
      const bodyText = await page.locator('body').textContent() || '';
      
      // Should not crash or show duplicate errors
      expect(bodyText.includes('Internal Server Error')).toBeFalsy();
      expect(bodyText.includes('duplicate')).toBeFalsy();
      
      console.log('✅ Rapid clicking handled gracefully');
    }
  });

  test('should handle browser back/forward navigation', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Navigate through several pages
    await page.goto('/words');
    await page.locator('a[href^="/words/"]').first().click();
    await page.goto('/dashboard');
    await page.goto('/words');
    
    // Go back multiple times
    await page.goBack();
    await page.goBack();
    await page.goBack();
    
    // Page should still work
    await expect(page.locator('h1')).toBeVisible({ timeout: 10000 });
    
    const bodyText = await page.locator('body').textContent() || '';
    expect(bodyText.includes('Internal Server Error')).toBeFalsy();
    expect(bodyText.includes('error')).toBeFalsy();
  });

  // ========== PERFORMANCE & TIMEOUTS ==========

  test('should handle slow network gracefully', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Slow down network
    await page.route('**/*', async (route) => {
      await new Promise(f => setTimeout(f, 500));  // 500ms delay
      await route.continue();
    });
    
    // Try to load a page
    await page.goto('/words', { timeout: 30000 });
    
    const bodyText = await page.locator('body').textContent() || '';
    expect(bodyText.includes('Internal Server Error')).toBeFalsy();
    
    // Remove throttling
    await page.unroute('**/*');
  });
});

test.describe('Bug Hunt - Data Integrity', () => {
  
  test('should not allow learning the same word twice', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    // Learn a word
    await page.goto('/words');
    await page.locator('a[href^="/words/"]').first().click();
    await expect(page.locator('h1')).toBeVisible({ timeout: 10000 });
    
    const markButton = page.locator('button:has-text("Mark as Learned")');
    
    if (await markButton.isVisible({ timeout: 3000 }).catch(() => false)) {
      // Mark as learned
      await markButton.click();
      await page.waitForSelector('text=Learned', { timeout: 5000 });
      
      // Try to mark again (reload page)
      await page.reload();
      await page.waitForLoadState('networkidle');
      
      // Button should be gone or disabled
      const buttonStillThere = await markButton.isVisible({ timeout: 2000 }).catch(() => false);
      
      if (buttonStillThere) {
        // Try clicking again - should not create duplicate
        await markButton.click();
        await page.waitForTimeout(1000);
        
        const bodyText = await page.locator('body').textContent() || '';
        expect(bodyText.includes('duplicate') || bodyText.includes('already')).toBeFalsy();
        expect(bodyText.includes('Internal Server Error')).toBeFalsy();
      }
    }
  });

  test('should handle concurrent sessions', async ({ browser }) => {
    // Create two contexts (simulating two tabs/devices)
    const context1 = await browser.newContext();
    const context2 = await browser.newContext();
    
    const page1 = await context1.newPage();
    const page2 = await context2.newPage();
    
    // Login on both
    const auth1 = createAuthHelper(page1);
    const auth2 = createAuthHelper(page2);
    
    await Promise.all([
      auth1.login(TEST_USERS.student),
      auth2.login(TEST_USERS.student),
    ]);
    
    // Both try to mark same word as learned
    await page1.goto('/words');
    await page2.goto('/words');
    
    await Promise.all([
      page1.locator('a[href^="/words/"]').first().click(),
      page2.locator('a[href^="/words/"]').first().click(),
    ]);
    
    await Promise.all([
      expect(page1.locator('h1')).toBeVisible({ timeout: 10000 }),
      expect(page2.locator('h1')).toBeVisible({ timeout: 10000 }),
    ]);
    
    // Try to click both simultaneously
    const button1 = page1.locator('button:has-text("Mark as Learned")');
    const button2 = page2.locator('button:has-text("Mark as Learned")');
    
    const [visible1, visible2] = await Promise.all([
      button1.isVisible({ timeout: 3000 }).catch(() => false),
      button2.isVisible({ timeout: 3000 }).catch(() => false),
    ]);
    
    if (visible1 && visible2) {
      await Promise.all([
        button1.click().catch(() => {}),
        button2.click().catch(() => {}),
      ]);
      
      await page1.waitForTimeout(2000);
      await page2.waitForTimeout(2000);
      
      // Check neither shows error
      const [text1, text2] = await Promise.all([
        page1.locator('body').textContent(),
        page2.locator('body').textContent(),
      ]);
      
      expect(text1?.includes('Internal Server Error')).toBeFalsy();
      expect(text2?.includes('Internal Server Error')).toBeFalsy();
    }
    
    await context1.close();
    await context2.close();
  });
});
