defmodule Medoru.Release do
  @moduledoc """
  Release tasks for Medoru.

  These tasks are meant to be run in production releases using:

      bin/medoru eval "Medoru.Release.make_admin(\"user@example.com\")"

  """

  @app :medoru

  alias Medoru.Accounts

  @doc """
  Makes a user an admin by email.

  ## Examples

      bin/medoru eval "Medoru.Release.make_admin(\"user@example.com\")"

  """
  def make_admin(email) when is_binary(email) do
    load_app()
    load_database()

    case Accounts.get_user_by_email_for_admin(email) do
      nil ->
        IO.puts("Error: User with email '#{email}' not found.")
        System.halt(1)

      user ->
        case Accounts.update_user_type(user, "admin") do
          {:ok, updated_user} ->
            IO.puts("✓ Successfully made '#{email}' an admin!")
            IO.puts("  User ID: #{updated_user.id}")
            IO.puts("  Type: #{updated_user.type}")

          {:error, changeset} ->
            IO.puts("Error: Failed to update user:")
            print_errors(changeset)
            System.halt(1)
        end
    end
  end

  @doc """
  Shows the version of the application.
  """
  def version do
    load_app()
    IO.puts(Application.spec(@app, :vsn))
  end

  @doc """
  Runs database migrations.
  """
  def migrate do
    load_app()
    load_database()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    IO.puts("Database migrations completed successfully.")
  end

  @doc """
  Rolls back database migrations.
  """
  def rollback(repo, version) do
    load_app()
    load_database()

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))

    IO.puts("Database rollback completed successfully.")
  end

  @doc """
  Seeds the database.
  """
  def seed do
    load_app()
    load_database()

    Medoru.Release.Seeds.run()
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(@app)
  end

  defp load_database do
    Application.ensure_all_started(:ecto_sql)

    for repo <- repos() do
      case repo.start_link(pool_size: 2) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
        error -> error
      end
    end
  end

  defp print_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.each(fn {field, errors} ->
      IO.puts("  #{field}: #{Enum.join(errors, ", ")}")
    end)
  end
end
