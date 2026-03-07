defmodule Mix.Tasks.Medoru.MakeAdmin do
  @moduledoc """
  Makes a user an admin by email.

  ## Examples

      mix medoru.make_admin user@example.com

  """
  use Mix.Task

  alias Medoru.Accounts

  @requirements ["app.start"]

  @impl true
  def run(args) do
    case args do
      [email] ->
        make_admin(email)

      _ ->
        Mix.shell().error("Usage: mix medoru.make_admin user@example.com")
        exit({:shutdown, 1})
    end
  end

  defp make_admin(email) do
    case Accounts.get_user_by_email_for_admin(email) do
      nil ->
        Mix.shell().error("User with email '#{email}' not found.")
        exit({:shutdown, 1})

      user ->
        case Accounts.update_user_type(user, "admin") do
          {:ok, updated_user} ->
            Mix.shell().info("✓ Successfully made '#{email}' an admin!")
            Mix.shell().info("  User ID: #{updated_user.id}")
            Mix.shell().info("  Type: #{updated_user.type}")

          {:error, changeset} ->
            Mix.shell().error("Failed to update user:")
            print_errors(changeset)
            exit({:shutdown, 1})
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
      Mix.shell().error("  #{field}: #{Enum.join(errors, ", ")}")
    end)
  end
end
