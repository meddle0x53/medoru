const Theme = {
  mounted() {
    this.handleEvent("set_theme", ({theme}) => {
      if (theme === "system") {
        localStorage.removeItem("phx:theme")
        document.documentElement.removeAttribute("data-theme")
      } else {
        localStorage.setItem("phx:theme", theme)
        document.documentElement.setAttribute("data-theme", theme)
      }
    })
  },
}

export default Theme
