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

async function subscribeToPush() {
  if (!swRegistration || !VAPID_KEY) {
    console.log("[Push] SW or VAPID key not available")
    return false
  }

  try {
    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      console.log("[Push] Permission denied")
      return false
    }

    const subscription = await swRegistration.pushManager.subscribe({
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
  if (!swRegistration) return false

  try {
    const subscription = await swRegistration.pushManager.getSubscription()
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

  if (!("PushManager" in window)) {
    console.log("[Push] Push notifications not supported")
    return
  }

  // Check if already subscribed and sync with server
  const subscription = await registration.pushManager.getSubscription()
  if (subscription) {
    console.log("[Push] Already subscribed, re-syncing...")
    await subscribeToPush()
  }
}

export async function handleSubscribePush() {
  return await subscribeToPush()
}

export async function handleUnsubscribePush() {
  return await unsubscribeFromPush()
}
