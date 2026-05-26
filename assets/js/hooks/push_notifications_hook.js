import {
  isPushSupported,
  requestPushPermission,
  handleSubscribePush,
  handleUnsubscribePush,
} from "../push_notifications"

const PushNotificationsHook = {
  mounted() {
    this.isEnabled = this.el.dataset.enabled === "true"

    this.el.addEventListener("click", async (e) => {
      // Prevent LiveView's phx-click from firing — we'll handle it manually
      // after requesting permission within the user gesture context.
      e.preventDefault()
      e.stopImmediatePropagation()

      const support = isPushSupported()
      if (!support.supported) {
        console.error("[Push] Not supported:", support)
        this.pushEvent("push_subscription_failed", {
          reason: "not_supported",
          vapid_key_present: support.vapidKey,
          vapid_key_length: VAPID_KEY ? VAPID_KEY.length : 0,
          service_worker_ready: support.serviceWorker,
          push_manager_ready: support.pushManager,
          notification_ready: support.notification,
          permission_state: support.permission,
        })
        return
      }

      // If we're enabling, request permission first (must be in user gesture context)
      if (!this.isEnabled) {
        const { granted, state } = await requestPushPermission()
        if (!granted) {
          console.error("[Push] Permission denied:", state)
          this.pushEvent("push_subscription_failed", {
            reason: "permission_denied",
            state: state,
          })
          return
        }
      }

      // Permission is granted (or we're disabling), proceed with toggle
      this.pushEvent("toggle_push_notifications", {})
    })

    this.handleEvent("subscribe_push", async () => {
      const ok = await handleSubscribePush()
      if (!ok) {
        this.pushEvent("push_subscription_failed", { reason: "subscribe_failed" })
      }
    })

    this.handleEvent("unsubscribe_push", async () => {
      await handleUnsubscribePush()
    })
  },

  updated() {
    this.isEnabled = this.el.dataset.enabled === "true"
  },
}

export default PushNotificationsHook
