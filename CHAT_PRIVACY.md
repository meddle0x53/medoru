# Your Messages Are Private — Here's How

## The Short Version

**Medoru cannot read your private messages.** Not the developers, not the server, not anyone. Your messages are locked inside a digital envelope that only you and the person you're chatting with can open.

---

## How It Works (The Lockbox Analogy)

Imagine you and your friend want to exchange secret notes. You buy a special lockbox together:

1. **Each person gets their own unique key** — this key is created inside your browser and never leaves your device. We don't have a copy. We can't make a copy. If you lose it, we can't help you open old messages.

2. **Every conversation gets its own lockbox** — when you start chatting, your browsers secretly agree on a shared lockbox. The "combination" to this lockbox is stored on our server, but it's written in a secret code that only your personal key can decode.

3. **Before a message leaves your screen, it gets locked** — you type "Hello", hit send, and your browser instantly scrambles it into gibberish. The server only sees gibberish. It stores gibberish. It forwards gibberish.

4. **Your friend's browser unlocks it** — when the gibberish arrives, their browser uses the shared lockbox to unscramble it back into "Hello".

> The server is just a mail carrier that delivers locked boxes. It can never peek inside.

---

## What Medoru CAN See

- Who you're talking to
- When you sent a message
- That *something* was sent (but not what)

## What Medoru CANNOT See

- The actual text of your messages
- Photos or voice messages you send
- The shared lockbox combination
- Your personal key

---

## Why Do I Sometimes See "Request Key" or "Reset Encryption"?

Because your personal key lives **only on your device**, switching browsers or clearing your data is like losing your house key:

- **New browser / new device** = You don't have your key anymore. You need a friend who's still in the chat to "lend you a copy of the lockbox combination" (this is the "Request key" button).

- **Nobody is online to help** = Your friends' browsers are asleep, so they can't hear your request. The app will keep trying automatically every few seconds until someone comes back.

- **Everyone got new devices** = Nobody has the old lockbox combination anymore. In this rare case, someone can click **"Reset encryption"** — this throws away the old lockbox and creates a brand new one. **Old messages stay scrambled forever**, but you can start chatting again normally.

---

## Is It Really Secure?

Yes, for a normal chat app. Here's the honest breakdown:

| Threat | Are you protected? |
|--------|-------------------|
| Medoru developers reading your chats | ✅ Yes — impossible |
| Hackers stealing server data | ✅ Yes — they'd only get gibberish |
| Someone intercepting messages in transit | ✅ Yes — everything is scrambled |
| Someone with access to your unlocked phone | ❌ No — if they unlock your device, they can read anything |
| Government subpoenaing Medoru | ⚠️ Partially — they'd see *who* talked and *when*, but not *what* was said |

---

## One Important Trade-Off

Because we **genuinely cannot** read your messages, we also **genuinely cannot** recover them if you lose your key. There's no "Forgot password?" for encrypted chats. That's the price of real privacy.

If you want to keep access across devices, use **Chat Security Settings** to export your key and save it somewhere safe (like a password manager).
