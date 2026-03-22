defmodule MedoruWeb.Router do
  use MedoruWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MedoruWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug MedoruWeb.Plugs.SetLocale
    plug MedoruWeb.UserAuth, :fetch_current_user
    plug MedoruWeb.Plugs.RequestLogger
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # QA API pipeline - has session support but no CSRF for testing
  pipeline :qa_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :put_secure_browser_headers
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
      live "/users/:id/words", LearnedWordsLive.Index
      live "/lessons", LessonLive.Index
      live "/lessons/:id", LessonLive.Show
      live "/attribution", SettingsLive.Attribution
      live "/privacy", PrivacyLive
      live "/cookies", CookiesLive
    end
  end

  # Learn routes (can be accessed anonymously but progress tracking requires auth)
  scope "/", MedoruWeb do
    pipe_through :browser

    live_session :learn,
      on_mount: [{MedoruWeb.UserAuth, :default}] do
      live "/lessons/:lesson_id/learn", LearnLive
    end
  end

  # Lesson Test routes (require authentication)
  scope "/", MedoruWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :lesson_test,
      on_mount: [{MedoruWeb.UserAuth, :require_authenticated_user}] do
      live "/lessons/:lesson_id/test", LessonTestLive.Show
      live "/lessons/:lesson_id/test/complete", LessonTestLive.Complete
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
      live "/notifications", NotificationsLive
      live "/daily-review", DailyReviewLive
    end
  end

  # Daily Test routes (require authentication)
  scope "/", MedoruWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :daily_test,
      on_mount: [{MedoruWeb.UserAuth, :require_authenticated_user}] do
      live "/daily-test", DailyTestLive
      live "/daily-test/complete", DailyTestLive.Complete
    end
  end

  # Settings routes
  scope "/settings", MedoruWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :settings,
      on_mount: [{MedoruWeb.UserAuth, :require_authenticated_user}] do
      live "/profile", SettingsLive.Profile
      live "/language", SettingsLive.Language
      live "/data-privacy", SettingsLive.DataPrivacy
    end
  end

  # Public user profiles
  scope "/users", MedoruWeb do
    pipe_through :browser

    live_session :public_profiles,
      on_mount: [{MedoruWeb.UserAuth, :default}] do
      live "/:id", UserLive.Show
    end
  end

  # Teacher routes
  scope "/teacher", MedoruWeb.Teacher do
    pipe_through [:browser, :require_authenticated_user]

    live_session :teacher,
      on_mount: [
        {MedoruWeb.UserAuth, :require_authenticated_user},
        {MedoruWeb.Plugs.Teacher, :default}
      ] do
      live "/classrooms", ClassroomLive.Index
      live "/classrooms/new", ClassroomLive.New
      live "/classrooms/:id", ClassroomLive.Show
      live "/classrooms/:id/analytics", ClassroomLive.Analytics

      live "/tests", TestLive.Index
      live "/tests/new", TestLive.New
      live "/tests/:id", TestLive.Show
      live "/tests/:id/edit", TestLive.Edit
      live "/tests/:id/publish", TestLive.Publish

      live "/custom-lessons", CustomLessonLive.Index
      live "/custom-lessons/new", CustomLessonLive.New
      live "/custom-lessons/:id/edit", CustomLessonLive.Edit
      live "/custom-lessons/:id/publish", CustomLessonLive.Publish
    end
  end

  # Student classroom routes
  scope "/classrooms", MedoruWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :classrooms,
      on_mount: [{MedoruWeb.UserAuth, :require_authenticated_user}] do
      live "/", ClassroomLive.Index
      live "/join", ClassroomLive.Join
      live "/:id", ClassroomLive.Show
      live "/:id/rankings", ClassroomLive.Rankings
      live "/:id/tests/:test_id", ClassroomLive.Test
      live "/:id/tests/:test_id/results", ClassroomLive.TestResults
      live "/:id/custom-lessons/:lesson_id", ClassroomLive.CustomLesson
      live "/:id/custom-lessons/:lesson_id/test", ClassroomLive.CustomLessonTest
      live "/:id/custom-lessons/:lesson_id/complete", ClassroomLive.CustomLessonComplete
    end
  end

  # Admin routes
  scope "/admin", MedoruWeb.Admin do
    pipe_through [:browser, :require_authenticated_user]

    live_session :admin,
      on_mount: [
        {MedoruWeb.UserAuth, :require_authenticated_user},
        {MedoruWeb.Plugs.Admin, :default}
      ] do
      live "/", DashboardLive

      live "/users", UserLive.Index
      live "/users/:id/edit", UserLive.Edit

      live "/kanji", KanjiLive.Index
      live "/kanji/new", KanjiLive.Form, :new
      live "/kanji/:id/edit", KanjiLive.Form, :edit

      live "/words", WordLive.Index
      live "/words/new", WordLive.Form, :new
      live "/words/:id/edit", WordLive.Form, :edit

      live "/lessons", LessonLive.Index
      live "/lessons/new", LessonLive.Form, :new
      live "/lessons/:id/edit", LessonLive.Form, :edit
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

  # QA Routes - Only available in QA environment
  if Application.compile_env(:medoru, :qa_mode, false) do
    scope "/qa", MedoruWeb.QA do
      pipe_through :browser

      get "/bypass", BypassController, :index
      post "/bypass/login", BypassController, :login
      post "/bypass/logout", BypassController, :logout
    end

    scope "/qa", MedoruWeb.QA do
      pipe_through :qa_api

      post "/bypass/api/login", BypassController, :api_login
      get "/bypass/api/users", BypassController, :list_users
      get "/health", BypassController, :health
    end
  end
end
