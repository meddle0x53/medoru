const UserTimezone = {
  mounted() {
    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
      if (tz) {
        this.pushEvent("set_user_timezone", { timezone: tz })
      }
    } catch {
      // Browser doesn't support Intl timezone detection
    }
  }
}

export default UserTimezone
