/**
 * Daily Test - Simple Flow
 *
 * Student completes their daily test:
 * 1. Login
 * 2. Go to daily test
 * 3. If no test available, study a lesson first
 * 4. Complete daily test
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

test.describe('Daily Test Flow', () => {
  test('student completes daily test', async ({ page }) => {
    // Step 1: Login
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);

    // Step 2: Navigate to daily test
    await navigateTo(page, 'dailyTest');
    await page.waitForLoadState('networkidle');
    
    // Check for various states
    const pageTitle = await page.locator('h1').textContent().catch(() => '');
    const bodyText = await page.locator('body').textContent() || '';
    
    // State 1: Already completed today
    if (bodyText.includes('Daily Review Complete')) {
      console.log('✅ Daily test already completed today');
      return;
    }

    // State 2: No words to review - need to study first
    if (pageTitle.includes('Lessons') || bodyText.includes('Start a lesson')) {
      console.log('ℹ️ No daily test available - studying a lesson first');
      
      // Click on first lesson
      const firstLesson = page.locator('a[href*="/lessons/"]').first();
      if (await firstLesson.isVisible({ timeout: 5000 }).catch(() => false)) {
        await firstLesson.click();
        await page.waitForLoadState('networkidle');
        
        // Start the lesson
        const startButton = page.locator('a:has-text("Start Lesson"), button:has-text("Start Lesson"), a:has-text("Learn"), button:has-text("Learn")').first();
        if (await startButton.isVisible({ timeout: 5000 }).catch(() => false)) {
          await startButton.click();
          await page.waitForTimeout(2000);
          
          // Go through lesson pages
          for (let i = 0; i < 10; i++) {
            const continueButton = page.locator('a:has-text("Continue"), button:has-text("Continue"), a:has-text("Next"), button:has-text("Next")').first();
            if (await continueButton.isVisible({ timeout: 3000 }).catch(() => false)) {
              await continueButton.click();
              await page.waitForTimeout(1000);
            } else {
              break;
            }
          }
          
          // Try daily test again
          await navigateTo(page, 'dailyTest');
          await page.waitForLoadState('networkidle');
        }
      }
    }

    // State 3: On daily review page - do the test
    const onDailyReview = await page.locator('h1:has-text("Daily Review")').isVisible().catch(() => false);
    if (!onDailyReview) {
      console.log('ℹ️ Still no daily test available after studying');
      return;
    }

    console.log('📝 Starting daily test...');

    // Step 3: Answer questions until complete
    let questionCount = 0;
    const maxQuestions = 50; // Safety limit

    while (questionCount < maxQuestions) {
      questionCount++;
      
      // Wait for question to load
      await page.waitForTimeout(1000);
      
      // Check if we're done
      const url = page.url();
      if (url.includes('/daily-test/complete') || url.includes('complete')) {
        console.log(`✅ Test completed after ${questionCount} questions`);
        break;
      }

      const bodyText = await page.locator('body').textContent() || '';
      if (bodyText.includes('Daily Review Complete') || bodyText.includes('All caught up')) {
        console.log(`✅ Test completed after ${questionCount} questions`);
        break;
      }

      // Look for multiple choice options
      const optionButtons = await page.locator('button[phx-click="select_answer"]').all();

      if (optionButtons.length > 0) {
        // Click first option
        await optionButtons[0].click();
        await page.waitForTimeout(500);

        // Click Submit Answer button
        const submitButton = page.locator('button:has-text("Submit Answer")').first();
        if (await submitButton.isVisible({ timeout: 3000 }).catch(() => false)) {
          await submitButton.click();
          await page.waitForTimeout(1000);
        }
      } else {
        // Check for reading text question
        const meaningInput = page.locator('input[placeholder*="meaning"], input[name*="meaning"]').first();
        
        if (await meaningInput.isVisible({ timeout: 2000 }).catch(() => false)) {
          const readingInput = page.locator('input[placeholder*="reading"], input[name*="reading"]').first();
          
          await meaningInput.fill('test');
          if (await readingInput.isVisible({ timeout: 2000 }).catch(() => false)) {
            await readingInput.fill('test');
          }
          
          const submitButton = page.locator('button:has-text("Submit Answer")').first();
          if (await submitButton.isVisible({ timeout: 3000 }).catch(() => false)) {
            await submitButton.click();
            await page.waitForTimeout(1000);
          }
        } else {
          // No more questions
          break;
        }
      }

      // Handle Continue button after wrong answer
      const continueButton = page.locator('button:has-text("Continue")').first();
      if (await continueButton.isVisible({ timeout: 2000 }).catch(() => false)) {
        await continueButton.click();
        await page.waitForTimeout(800);
      }
    }

    // Step 4: Verify completion
    const finalUrl = page.url();
    const finalText = await page.locator('body').textContent() || '';
    
    const isComplete = 
      finalUrl.includes('complete') ||
      finalText.includes('Daily Review Complete') ||
      finalText.includes('Great job') ||
      finalText.includes('already completed');
    
    expect(isComplete).toBeTruthy();
    console.log('✅ Daily test flow completed successfully');
  });
});
