import { handleSubscribePush, handleUnsubscribePush } from "../push_notifications"

const PushNotificationsHook = {
  mounted() {
    this.handleEvent("subscribe_push", async () => {
      const ok = await handleSubscribePush()
      if (!ok) {
        // If subscription failed, tell the server to revert the toggle
        this.pushEvent("push_subscription_failed", {})
      }
    })

    this.handleEvent("unsubscribe_push", async () => {
      await handleUnsubscribePush()
    })
  }
}

export default PushNotificationsHook
