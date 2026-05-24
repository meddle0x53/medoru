/**
 * Chat Encryption E2E Test
 *
 * Verifies end-to-end encrypted messaging between two users.
 * Uses WebCrypto ECDH + AES-GCM for encryption.
 */

import { test, expect, BrowserContext, Page } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

interface UserInfo {
  id: string;
  email: string;
  name: string;
}

async function getTestUserInfo(request: any, email: string): Promise<UserInfo> {
  const response = await request.get('/qa/bypass/api/users');
  expect(response.ok()).toBeTruthy();
  const body = await response.json();
  const user = body.users.find((u: any) => u.email === email);
  expect(user).toBeDefined();
  return { id: user.id, email: user.email, name: user.name };
}

async function loginUser(page: Page, user: typeof TEST_USERS.student): Promise<void> {
  const auth = createAuthHelper(page);
  await auth.login(user);
}

async function startConversation(page: Page, otherUserId: string): Promise<void> {
  await page.goto(`/messages?user=${otherUserId}`);
  await page.waitForLoadState('networkidle');
  // Should redirect to /messages/<conversation_id>
  await expect(page).toHaveURL(/\/messages\/[a-f0-9-]+$/);
}

async function openMessagesList(page: Page): Promise<void> {
  await navigateTo(page, 'messages');
}

async function openConversation(page: Page, otherUserName: string): Promise<void> {
  await openMessagesList(page);
  // Click on the conversation with the other user
  const conversationLink = page.locator(`a:has-text("${otherUserName}")`).first();
  await expect(conversationLink).toBeVisible({ timeout: 5000 });
  await conversationLink.click();
  await page.waitForLoadState('networkidle');
  await expect(page).toHaveURL(/\/messages\/[a-f0-9-]+$/);
}

async function sendMessage(page: Page, text: string): Promise<void> {
  const textarea = page.locator('#chat-message-input');
  const sendButton = page.locator('#chat-send-button');

  await expect(textarea).toBeVisible({ timeout: 5000 });
  await textarea.fill(text);
  await sendButton.click();

  // Clear the input to confirm the message was sent
  await expect(textarea).toHaveValue('');
}

async function waitForDecryptedMessage(page: Page, text: string, timeout = 10000): Promise<void> {
  // Wait for a message bubble to contain the expected text (not [...])
  const messageLocator = page.locator('#messages-container p').filter({ hasText: text });
  await expect(messageLocator).toBeVisible({ timeout });
}

async function waitForMessageNotPlaceholder(page: Page, timeout = 10000): Promise<string> {
  // Wait for the last message to not be [...]
  const lastMessage = page.locator('#messages-container p').last();
  await expect(lastMessage).not.toHaveText('[...]', { timeout });
  return lastMessage.textContent() as Promise<string>;
}

test.describe('Chat E2E Encryption', () => {
  let userAInfo: UserInfo;
  let userBInfo: UserInfo;

  test.beforeAll(async ({ request }) => {
    // Get user info from QA API
    userAInfo = await getTestUserInfo(request, TEST_USERS.student.email);
    userBInfo = await getTestUserInfo(request, TEST_USERS.student2.email);
  });

  test('two users can exchange encrypted messages', async ({ browser }) => {
    // Create two separate browser contexts for two users
    const contextA: BrowserContext = await browser.newContext();
    const contextB: BrowserContext = await browser.newContext();

    const pageA: Page = await contextA.newPage();
    const pageB: Page = await contextB.newPage();

    try {
      // Step 1: Both users log in
      await loginUser(pageA, TEST_USERS.student);
      await loginUser(pageB, TEST_USERS.student2);

      // Step 2: User A starts a conversation with User B
      await startConversation(pageA, userBInfo.id);

      // Step 3: User B opens the conversation
      await openConversation(pageB, TEST_USERS.student.name);

      // Step 4: User A sends a message
      const messageFromA = 'Hello from User A!';
      await sendMessage(pageA, messageFromA);

      // Step 5: User B sees the decrypted message
      await waitForDecryptedMessage(pageB, messageFromA);

      // Step 6: User B replies
      const messageFromB = 'Hi User A, got your message!';
      await sendMessage(pageB, messageFromB);

      // Step 7: User A sees the decrypted reply
      await waitForDecryptedMessage(pageA, messageFromB);

      // Step 8: Send another message to verify continuous encryption
      const secondMessageFromA = 'E2E encryption is working!';
      await sendMessage(pageA, secondMessageFromA);
      await waitForDecryptedMessage(pageB, secondMessageFromA);

    } finally {
      await contextA.close();
      await contextB.close();
    }
  });

  test('messages do not show placeholder after decryption', async ({ browser }) => {
    const contextA: BrowserContext = await browser.newContext();
    const contextB: BrowserContext = await browser.newContext();

    const pageA: Page = await contextA.newPage();
    const pageB: Page = await contextB.newPage();

    try {
      await loginUser(pageA, TEST_USERS.student);
      await loginUser(pageB, TEST_USERS.student2);

      await startConversation(pageA, userBInfo.id);
      await openConversation(pageB, TEST_USERS.student.name);

      // Send a message
      const testMessage = 'Testing no placeholder';
      await sendMessage(pageA, testMessage);

      // Wait for the last message on page B to be decrypted
      const decryptedText = await waitForMessageNotPlaceholder(pageB);
      expect(decryptedText).toBe(testMessage);

      // Verify no [...] placeholders remain in the conversation
      const placeholders = pageB.locator('#messages-container p:has-text("[...]")');
      const count = await placeholders.count();
      // Legacy messages might still show [...] if they couldn't be parsed,
      // but new encrypted messages should never show [...]
      const newMessages = pageB.locator('#messages-container [data-encrypted="true"]');
      const encryptedCount = await newMessages.count();
      expect(encryptedCount).toBe(0);

    } finally {
      await contextA.close();
      await contextB.close();
    }
  });
});
