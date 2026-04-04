/**
 * Moderator Content Management Tests
 *
 * Tests that a moderator can add, edit, and delete words and kanji
 * through the moderator dashboard.
 */

import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

test.describe('Moderator Content Management', () => {
  const uniqueSuffix = Date.now().toString();

  test('moderator can add, edit and delete a word', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.moderator);

    // Use purely Japanese characters to pass validation
    // Generate a unique hiragana suffix to avoid "has already been taken" errors
    const hiragana = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん';
    const h1 = hiragana[parseInt(uniqueSuffix.slice(-3, -2)) % hiragana.length];
    const h2 = hiragana[parseInt(uniqueSuffix.slice(-2, -1)) % hiragana.length];
    const h3 = hiragana[parseInt(uniqueSuffix.slice(-1)) % hiragana.length];
    const jaSuffix = h1 + h2 + h3;

    const wordText = '試験単語' + jaSuffix;
    const wordReading = 'しけんたんご' + jaSuffix;
    const wordMeaning = `Test Word ${uniqueSuffix}`;
    const updatedMeaning = `Updated Test Word ${uniqueSuffix}`;

    // Navigate to moderator words page
    await navigateTo(page, '/moderator/words');

    // Verify page loaded
    await expect(page.locator('h1')).toContainText('Word Management');

    // Click Add Word
    await page.getByRole('link', { name: /Add Word/i }).click();
    await page.waitForLoadState('networkidle');

    // Fill word form
    await page.locator('input[name="word[text]"]').fill(wordText);
    await page.locator('input[name="word[reading]"]').fill(wordReading);
    await page.locator('input[name="word[meaning]"]').fill(wordMeaning);
    await page.locator('select[name="word[difficulty]"]').selectOption('5');
    await page.locator('select[name="word[word_type]"]').selectOption('noun');
    await page.locator('input[name="word[usage_frequency]"]').fill('999');
    await page.locator('input[name="word[example_sentence]"]').fill('これはテストです。');
    await page.locator('input[name="word[example_reading]"]').fill('これはてすとです。');
    await page.locator('input[name="word[example_meaning]"]').fill('This is a test.');
    await page.locator('input[name="word[translations][bg][meaning]"]').fill('тестова дума');
    await page.locator('input[name="word[translations][ja][meaning]"]').fill('テストの単語');

    // Submit form
    await page.getByRole('button', { name: /Create Word/i }).click();
    await page.waitForLoadState('networkidle');

    // Should redirect back to words list with success message
    await expect(page).toHaveURL(/\/moderator\/words/);
    await expect(page.locator('body')).toContainText('Word created successfully');

    // Verify word appears in list (desktop table)
    await expect(page.locator('td.max-w-xs.truncate:has-text("' + wordMeaning + '")').first()).toBeVisible();

    // Click edit
    const wordRow = page.locator('tr:has-text("' + wordMeaning + '")');
    await wordRow.locator('a[title="Edit"]').click();
    await page.waitForLoadState('networkidle');

    // Update meaning
    await page.locator('input[name="word[meaning]"]').fill(updatedMeaning);
    await page.getByRole('button', { name: /Update Word/i }).click();
    await page.waitForLoadState('networkidle');

    // Verify update success on edit page (edit form stays on the same page)
    await expect(page.locator('body')).toContainText('Word updated successfully');

    // Navigate back to words list to verify the update is reflected
    await page.goto('/moderator/words');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('td.max-w-xs.truncate:has-text("' + updatedMeaning + '")').first()).toBeVisible();

    // Delete the word
    const updatedRow = page.locator('tr:has-text("' + updatedMeaning + '")');
    page.once('dialog', async (dialog) => {
      await dialog.accept();
    });
    await updatedRow.locator('button[title="Delete"]').click();
    await page.waitForLoadState('networkidle');

    // Verify deletion
    await expect(page.locator('body')).toContainText('Word deleted successfully');
    await expect(page.locator('text=' + updatedMeaning)).not.toBeVisible();
  });

  test('moderator can add, edit and delete a kanji', async ({ page }) => {
    const auth = createAuthHelper(page);
    await auth.login(TEST_USERS.moderator);

    // Use a pool of rare kanji to avoid collisions
    const rareKanji = ['鱗', '鱶', '鯵', '鰯', '鰤', '鰈', '鮃', '鮎', '鮑', '鯛'];
    const character = rareKanji[parseInt(uniqueSuffix.slice(-2)) % rareKanji.length];
    const meanings = `test, examination ${uniqueSuffix}`;
    const updatedMeanings = `test, exam, trial ${uniqueSuffix}`;

    // Navigate to moderator kanji page
    await navigateTo(page, '/moderator/kanji');

    // Verify page loaded
    await expect(page.locator('h1')).toContainText('Kanji Management');

    // Click Add Kanji
    await page.getByRole('link', { name: /Add Kanji/i }).click();
    await page.waitForLoadState('networkidle');

    // Fill kanji form
    await page.locator('input[name="kanji[character]"]').fill(character);
    await page.locator('input[name="kanji[meanings]"]').fill(meanings);
    await page.locator('select[name="kanji[jlpt_level]"]').selectOption('3');
    await page.locator('input[name="kanji[stroke_count]"]').fill('8');
    await page.locator('input[name="kanji[frequency]"]').fill('500');
    await page.locator('input[name="kanji[translations][bg][meanings]"]').fill('изпитване, тест');
    await page.locator('input[name="kanji[translations][ja][meanings]"]').fill('試験、テスト');

    // Submit form
    await page.getByRole('button', { name: /Create Kanji/i }).click();
    await page.waitForLoadState('networkidle');

    // Should redirect back to kanji list with success message
    await expect(page).toHaveURL(/\/moderator\/kanji/);
    await expect(page.locator('body')).toContainText('Kanji created successfully');

    // Verify kanji appears in list
    await expect(page.locator('.text-5xl:has-text("' + character + '")').first()).toBeVisible();

    // Click edit
    const kanjiCard = page.locator('.card:has(.text-5xl:has-text("' + character + '"))');
    await kanjiCard.locator('a[title="Edit"]').click();
    await page.waitForLoadState('networkidle');

    // Update meanings
    await page.locator('input[name="kanji[meanings]"]').fill(updatedMeanings);
    await page.getByRole('button', { name: /Update Kanji/i }).click();
    await page.waitForLoadState('networkidle');

    // Verify update
    await expect(page).toHaveURL(/\/moderator\/kanji/);
    await expect(page.locator('body')).toContainText('Kanji updated successfully');

    // Delete the kanji
    const updatedCard = page.locator('.card:has(.text-5xl:has-text("' + character + '"))');
    page.once('dialog', async (dialog) => {
      await dialog.accept();
    });
    await updatedCard.locator('button[title="Delete"]').click();
    await page.waitForLoadState('networkidle');

    // Verify deletion
    await expect(page.locator('body')).toContainText('Kanji deleted successfully');
    await expect(page.locator('.text-5xl:has-text("' + character + '")').first()).not.toBeVisible();
  });
});
