/**
 * Push notification subscription management for PWA.
 * Handles subscribing/unsubscribing to Web Push notifications.
 */

const VAPID_KEY = window.medoruVapidKey
let swRegistration = null

function urlBase64ToUint8Array(base64String) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }
  return outputArray
}

function getCsrfToken() {
  const meta = document.querySelector("meta[name='csrf-token']")
  return meta ? meta.getAttribute("content") : ""
}

export function isPushSupported() {
  const swReady = "serviceWorker" in navigator
  const pushReady = "PushManager" in window
  const notificationReady = "Notification" in window
  const vapidReady = !!VAPID_KEY
  return {
    supported: swReady && pushReady && notificationReady && vapidReady,
    serviceWorker: swReady,
    pushManager: pushReady,
    notification: notificationReady,
    vapidKey: vapidReady,
    permission: notificationReady ? Notification.permission : "unsupported",
  }
}

export async function requestPushPermission() {
  if (!("Notification" in window)) {
    return { granted: false, state: "unsupported" }
  }

  // If already granted, return immediately without showing a prompt
  if (Notification.permission === "granted") {
    return { granted: true, state: "granted" }
  }

  // If already denied, we can't ask again
  if (Notification.permission === "denied") {
    return { granted: false, state: "denied" }
  }

  // Request permission (this will show the browser prompt)
  const result = await Notification.requestPermission()
  return { granted: result === "granted", state: result }
}

async function getSwRegistration() {
  if (swRegistration) return swRegistration
  if ("serviceWorker" in navigator) {
    swRegistration = await navigator.serviceWorker.ready
    return swRegistration
  }
  return null
}

async function subscribeToPush() {
  const support = isPushSupported()
  if (!support.supported) {
    console.error("[Push] Not supported:", support)
    return false
  }

  try {
    // Ensure service worker is ready
    const reg = await getSwRegistration()
    if (!reg) {
      console.error("[Push] Service worker not available")
      return false
    }

    // Check permission (should already be granted if user clicked through hook)
    if (Notification.permission !== "granted") {
      console.error("[Push] Permission not granted:", Notification.permission)
      return false
    }

    const subscription = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_KEY),
    })

    const payload = {
      subscription: {
        endpoint: subscription.endpoint,
        keys: {
          p256dh: btoa(
            String.fromCharCode.apply(
              null,
              new Uint8Array(subscription.getKey("p256dh"))
            )
          )
            .replace(/\+/g, "-")
            .replace(/\//g, "_")
            .replace(/=/g, ""),
          auth: btoa(
            String.fromCharCode.apply(
              null,
              new Uint8Array(subscription.getKey("auth"))
            )
          )
            .replace(/\+/g, "-")
            .replace(/\//g, "_")
            .replace(/=/g, ""),
        },
      },
    }

    const response = await fetch("/api/push-subscribe", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-csrf-token": getCsrfToken(),
      },
      body: JSON.stringify(payload),
    })

    if (response.ok) {
      console.log("[Push] Subscribed successfully")
      return true
    } else {
      console.error("[Push] Subscription failed:", await response.text())
      return false
    }
  } catch (err) {
    console.error("[Push] Subscribe error:", err)
    return false
  }
}

async function unsubscribeFromPush() {
  const reg = await getSwRegistration()
  if (!reg) return false

  try {
    const subscription = await reg.pushManager.getSubscription()
    if (subscription) {
      await subscription.unsubscribe()

      await fetch("/api/push-subscribe", {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "x-csrf-token": getCsrfToken(),
        },
        body: JSON.stringify({ endpoint: subscription.endpoint }),
      })

      console.log("[Push] Unsubscribed successfully")
    }
    return true
  } catch (err) {
    console.error("[Push] Unsubscribe error:", err)
    return false
  }
}

export async function initPushNotifications(registration) {
  swRegistration = registration

  const support = isPushSupported()
  if (!support.supported) {
    console.log("[Push] Push notifications not supported:", support)
    return
  }

  // Check if already subscribed and sync with server
  try {
    const subscription = await registration.pushManager.getSubscription()
    if (subscription) {
      console.log("[Push] Already subscribed, re-syncing...")
      await subscribeToPush()
    }
  } catch (err) {
    console.error("[Push] Error checking subscription:", err)
  }
}

export async function handleSubscribePush() {
  return await subscribeToPush()
}

export async function handleUnsubscribePush() {
  return await unsubscribeFromPush()
}
