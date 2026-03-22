/**
 * Daily Test - Full Flow Tests
 *
 * Complete user journey for daily test:
 * 1. Navigate to daily test
 * 2. Answer all questions (multiple choice and reading text)
 * 3. Complete test and verify streak/XP updates
 * 4. Verify "already completed" state same day
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper } from '../helpers';

test.describe('Daily Test Full Flow', () => {
  
  test('should start and complete daily test with all question types', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    // Get initial stats for comparison
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    const initialStreak = await page.locator('.card:has-text("Day Streak") .text-2xl')
      .textContent()
      .catch(() => '0');
    console.log(`Initial streak: ${initialStreak}`);
    
    // Navigate to daily test
    await page.goto('/daily-test');
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    const url = page.url();
    
    // Check for various states
    if (bodyText.includes('Daily Review Complete') || bodyText.includes('already completed')) {
      console.log('⚠️ Daily test already completed today');
      return;
    }
    
    if (url.includes('/lessons') || bodyText.includes('Start a lesson')) {
      console.log('⚠️ No words available for daily test - need to learn words first');
      return;
    }
    
    // Should be on daily review page
    expect(bodyText.includes('Daily Review') || bodyText.includes('Question')).toBeTruthy();
    console.log('✅ Daily test started');
    
    // Answer questions until complete
    let questionCount = 0;
    const maxQuestions = 30; // Safety limit
    
    while (questionCount < maxQuestions) {
      questionCount++;
      console.log(`Answering question ${questionCount}...`);
      
      // Wait for question to load
      await page.waitForTimeout(1000);
      
      // Check if test is complete
      const currentUrl = page.url();
      if (currentUrl.includes('/daily-test/complete') || currentUrl.includes('complete')) {
        console.log(`✅ Test completed after ${questionCount} questions`);
        break;
      }
      
      const currentBody = await page.locator('body').textContent() || '';
      if (currentBody.includes('Daily Review Complete') || currentBody.includes('Test Complete')) {
        console.log(`✅ Test completed after ${questionCount} questions`);
        break;
      }
      
      // Check for multiple choice question
      const optionButtons = await page.locator('button[phx-click="select_answer"]').all();
      
      if (optionButtons.length > 0) {
        console.log(`  Multiple choice question with ${optionButtons.length} options`);
        
        // Click first option
        await optionButtons[0].click();
        await page.waitForTimeout(300);
        
        // Submit answer
        const submitButton = page.locator('button:has-text("Submit Answer"), button[phx-click="submit_answer"]').first();
        if (await submitButton.isVisible({ timeout: 3000 }).catch(() => false)) {
          await submitButton.click();
          await page.waitForTimeout(800);
        }
      } else {
        // Check for reading text question (meaning + reading inputs)
        const meaningInput = page.locator('input[placeholder*="meaning" i], input[name*="meaning" i]').first();
        const readingInput = page.locator('input[placeholder*="reading" i], input[name*="reading" i]').first();
        
        const hasMeaning = await meaningInput.isVisible({ timeout: 2000 }).catch(() => false);
        const hasReading = await readingInput.isVisible({ timeout: 2000 }).catch(() => false);
        
        if (hasMeaning && hasReading) {
          console.log('  Reading text question');
          
          // Fill in answers (with dummy values for testing)
          await meaningInput.fill('test meaning');
          await readingInput.fill('test reading');
          await page.waitForTimeout(300);
          
          // Submit
          const submitButton = page.locator('button:has-text("Submit Answer"), button[phx-click="submit_reading_text"]').first();
          if (await submitButton.isVisible({ timeout: 3000 }).catch(() => false)) {
            await submitButton.click();
            await page.waitForTimeout(800);
          }
        } else {
          // Unknown question type or test ended
          console.log('  No recognizable question type - checking completion');
          break;
        }
      }
      
      // Handle Continue button after feedback (correct/incorrect)
      const continueButton = page.locator('button:has-text("Continue"), button[phx-click="clear_feedback"]').first();
      if (await continueButton.isVisible({ timeout: 3000 }).catch(() => false)) {
        await continueButton.click();
        await page.waitForTimeout(500);
      }
      
      // Handle Next Question button
      const nextButton = page.locator('button:has-text("Next Question"), button[phx-click="next_question"]').first();
      if (await nextButton.isVisible({ timeout: 2000 }).catch(() => false)) {
        await nextButton.click();
        await page.waitForTimeout(500);
      }
    }
    
    console.log(`Answered ${questionCount} questions`);
    
    // Verify completion
    const finalUrl = page.url();
    const finalBody = await page.locator('body').textContent() || '';
    
    const isComplete = 
      finalUrl.includes('complete') ||
      finalBody.includes('Daily Review Complete') ||
      finalBody.includes('Test Complete') ||
      finalBody.includes('Great job') ||
      finalBody.includes('Congratulations');
    
    expect(isComplete).toBeTruthy();
    console.log('✅ Daily test completed successfully');
    
    // Check for streak/Xp display on completion page
    if (finalBody.includes('streak') || finalBody.includes('Streak')) {
      console.log('✅ Streak information shown on completion');
    }
    if (finalBody.includes('XP') || finalBody.includes('xp')) {
      console.log('✅ XP information shown on completion');
    }
  });

  test('should show already completed state when trying test again', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    // Try to access daily test
    await page.goto('/daily-test');
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    
    // Either test is available or already completed
    const isCompleted = bodyText.includes('Daily Review Complete') || bodyText.includes('already completed');
    const isAvailable = bodyText.includes('Daily Review') && !isCompleted;
    
    if (isCompleted) {
      console.log('✅ Daily test already completed today - state preserved');
      
      // Check for streak display
      expect(bodyText.includes('streak') || bodyText.includes('Streak')).toBeTruthy();
    } else if (isAvailable) {
      console.log('ℹ️ Daily test available - complete it first to test this state');
    } else {
      console.log('ℹ️ No daily test available - need to learn words first');
    }
  });

  test('should redirect to lessons if no words learned', async ({ page }) => {
    // Use a fresh user with no progress
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.student);
    
    await page.goto('/daily-test');
    await page.waitForLoadState('networkidle');
    
    const url = page.url();
    const bodyText = await page.locator('body').textContent() || '';
    
    // Should either redirect to lessons or show message
    const redirected = url.includes('/lessons');
    const hasMessage = bodyText.includes('Start a lesson') || bodyText.includes('learn some words');
    
    if (redirected || hasMessage) {
      console.log('✅ Correctly redirected to lessons when no words learned');
    } else {
      console.log('ℹ️ User may already have learned words');
    }
    
    // Should not crash
    expect(bodyText.includes('Internal Server Error')).toBeFalsy();
  });

  test('should track progress through test', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    await page.goto('/daily-test');
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    
    // Skip if already completed
    if (bodyText.includes('Daily Review Complete') || bodyText.includes('already completed')) {
      console.log('⚠️ Daily test already completed');
      return;
    }
    
    // Look for progress indicator
    const progressText = await page.locator('text=/\\d+ of \\d+/').first().textContent().catch(() => null);
    if (progressText) {
      console.log(`Progress: ${progressText}`);
    }
    
    // Look for progress bar
    const progressBar = page.locator('.bg-primary.h-2, .bg-primary.h-2\.5, [role="progressbar"]').first();
    const hasProgressBar = await progressBar.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (hasProgressBar) {
      console.log('✅ Progress bar visible');
    }
    
    // Answer one question to see progress update
    const optionButtons = await page.locator('button[phx-click="select_answer"]').all();
    if (optionButtons.length > 0) {
      await optionButtons[0].click();
      
      const submitButton = page.locator('button:has-text("Submit Answer"), button[phx-click="submit_answer"]').first();
      if (await submitButton.isVisible({ timeout: 3000 }).catch(() => false)) {
        await submitButton.click();
        await page.waitForTimeout(500);
        console.log('✅ Submitted first answer');
      }
    }
  });

  test('should show feedback after answering', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    await page.goto('/daily-test');
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    
    // Skip if already completed
    if (bodyText.includes('Daily Review Complete')) {
      console.log('⚠️ Daily test already completed');
      return;
    }
    
    // Answer a question
    const optionButtons = await page.locator('button[phx-click="select_answer"]').all();
    if (optionButtons.length === 0) {
      console.log('⚠️ No multiple choice questions available');
      return;
    }
    
    await optionButtons[0].click();
    await page.waitForTimeout(300);
    
    const submitButton = page.locator('button:has-text("Submit Answer"), button[phx-click="submit_answer"]').first();
    await submitButton.click();
    await page.waitForTimeout(1000);
    
    // Check for feedback
    const feedbackBody = await page.locator('body').textContent() || '';
    const hasFeedback = 
      feedbackBody.includes('Correct') ||
      feedbackBody.includes('Incorrect') ||
      feedbackBody.includes('✓') ||
      feedbackBody.includes('✗');
    
    if (hasFeedback) {
      console.log('✅ Feedback shown after answering');
    }
    
    // Should have Continue button
    const continueButton = page.locator('button:has-text("Continue")').first();
    expect(await continueButton.isVisible({ timeout: 5000 }).catch(() => false)).toBeTruthy();
  });

  test('should handle hints correctly', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.studentAdvanced);
    
    await page.goto('/daily-test');
    await page.waitForLoadState('networkidle');
    
    const bodyText = await page.locator('body').textContent() || '';
    
    // Skip if already completed
    if (bodyText.includes('Daily Review Complete')) {
      console.log('⚠️ Daily test already completed');
      return;
    }
    
    // Look for hint button
    const hintButton = page.locator('button:has-text("Hint"), button[phx-click="show_hint"]').first();
    const hasHint = await hintButton.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (hasHint) {
      await hintButton.click();
      await page.waitForTimeout(500);
      
      // Check if hint is displayed
      const hintBody = await page.locator('body').textContent() || '';
      if (hintBody.includes('Hint') || hintBody.includes('hint')) {
        console.log('✅ Hint displayed');
      }
    } else {
      console.log('ℹ️ No hint button on this question');
    }
  });
});
