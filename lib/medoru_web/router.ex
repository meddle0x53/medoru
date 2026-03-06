defmodule MedoruWeb.Router do
  use MedoruWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MedoruWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug MedoruWeb.UserAuth, :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_authenticated_user do
    plug MedoruWeb.UserAuth, :require_authenticated_user
  end

  # Public routes
  scope "/", MedoruWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :public,
      on_mount: [{MedoruWeb.UserAuth, :default}] do
      live "/kanji", KanjiLive.Index
      live "/kanji/:id", KanjiLive.Show
      live "/words", WordLive.Index
      live "/words/:id", WordLive.Show
    end
  end

  # OAuth routes
  scope "/auth", MedoruWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    post "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :logout
  end

  # Authenticated routes
  scope "/", MedoruWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated,
      on_mount: [{MedoruWeb.UserAuth, :require_authenticated_user}] do
      live "/dashboard", DashboardLive
      # Placeholder routes for future iterations
      live "/lessons", DashboardLive, :lessons_placeholder
      live "/daily-review", DashboardLive, :daily_review_placeholder
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", MedoruWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:medoru, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can add your own admin authentication plug here.
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MedoruWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
