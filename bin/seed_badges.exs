#!/usr/bin/env elixir
# Script for seeding badges into production (or any environment)
# Safe to run multiple times — skips existing badges.
#
# Usage on production (via release or local mix):
#   mix run bin/seed_badges.exs
# Or inside a release container:
#   /app/bin/medoru eval 'Code.eval_file("bin/seed_badges.exs")'
#
require Logger

alias Medoru.Gamification

badges_path = Path.join([__DIR__, "..", "priv", "repo", "seeds", "badges.json"])

unless File.exists?(badges_path) do
  Logger.error("Badges seed file not found: #{badges_path}")
  System.halt(1)
end

data = File.read!(badges_path) |> Jason.decode!()
badges = if is_list(data), do: data, else: data["badges"] || []

IO.puts("Seeding #{length(badges)} badges...")

seeded =
  Enum.reduce(badges, {0, 0}, fn b, {created, skipped} ->
    attrs = %{
      name: b["name"],
      description: b["description"],
      icon: b["icon"],
      color: b["color"],
      criteria_type: String.to_atom(b["criteria_type"]),
      criteria_value: b["criteria_value"],
      order_index: b["order_index"]
    }

    case Gamification.create_badge(attrs) do
      {:ok, _} ->
        {created + 1, skipped}

      {:error, _} ->
        IO.puts("  ⚠ #{b["name"]} (already exists)")
        {created, skipped + 1}
    end
  end)

{created_count, skipped_count} = seeded

IO.puts("")
IO.puts("✅ Badge seeding complete!")
IO.puts("   Created: #{created_count}")
IO.puts("   Skipped: #{skipped_count}")
IO.puts("   Total in DB: #{Enum.count(Gamification.list_badges())}")
