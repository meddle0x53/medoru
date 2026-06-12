defmodule MedoruWeb.Admin.TagLive.Form do
  @moduledoc """
  Admin form for creating and editing tags.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.CoreComponents

  alias Medoru.Social
  alias Medoru.Social.Tag

  embed_templates "form/*"

  @categories [
    {"Level", "level"},
    {"Music", "music"},
    {"Movies", "movies"},
    {"Literature", "literature"},
    {"Gaming", "gaming"},
    {"Lifestyle", "lifestyle"},
    {"Sport", "sport"},
    {"Goal", "goal"}
  ]

  @colors [
    "red",
    "orange",
    "amber",
    "yellow",
    "lime",
    "green",
    "emerald",
    "teal",
    "cyan",
    "sky",
    "blue",
    "indigo",
    "violet",
    "purple",
    "fuchsia",
    "pink",
    "rose",
    "slate",
    "stone",
    "primary",
    "secondary",
    "accent",
    "info",
    "success",
    "warning",
    "error"
  ]

  @impl true
  def render(assigns) do
    ~H"""
    {form_template(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:categories, @categories)
     |> assign(:colors, @colors)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    changeset = Social.change_tag(%Tag{})

    socket
    |> assign(:page_title, gettext("Add New Tag"))
    |> assign(:tag, %Tag{})
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    tag = Social.get_tag!(id)
    changeset = Social.change_tag(tag)

    socket
    |> assign(:page_title, gettext("Edit Tag - %{name}", name: tag.name))
    |> assign(:tag, tag)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("validate", %{"tag" => tag_params}, socket) do
    changeset =
      socket.assigns.tag
      |> Social.change_tag(tag_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"tag" => tag_params}, socket) do
    save_tag(socket, socket.assigns.live_action, tag_params)
  end

  defp save_tag(socket, :new, tag_params) do
    case Social.create_tag(tag_params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Tag created successfully."))
         |> push_navigate(to: ~p"/admin/tags")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_tag(socket, :edit, tag_params) do
    case Social.update_tag(socket.assigns.tag, tag_params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Tag updated successfully."))
         |> push_navigate(to: ~p"/admin/tags")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @doc """
  Maps tag color names to Tailwind bg/text classes.
  Uses explicit pattern matches so Tailwind JIT picks up the classes.
  """
  def tag_color_classes("red"), do: "bg-red-500 text-white"
  def tag_color_classes("orange"), do: "bg-orange-500 text-white"
  def tag_color_classes("amber"), do: "bg-amber-500 text-white"
  def tag_color_classes("yellow"), do: "bg-yellow-400 text-black"
  def tag_color_classes("lime"), do: "bg-lime-500 text-white"
  def tag_color_classes("green"), do: "bg-green-500 text-white"
  def tag_color_classes("emerald"), do: "bg-emerald-500 text-white"
  def tag_color_classes("teal"), do: "bg-teal-500 text-white"
  def tag_color_classes("cyan"), do: "bg-cyan-500 text-white"
  def tag_color_classes("sky"), do: "bg-sky-500 text-white"
  def tag_color_classes("blue"), do: "bg-blue-500 text-white"
  def tag_color_classes("indigo"), do: "bg-indigo-500 text-white"
  def tag_color_classes("violet"), do: "bg-violet-500 text-white"
  def tag_color_classes("purple"), do: "bg-purple-500 text-white"
  def tag_color_classes("fuchsia"), do: "bg-fuchsia-500 text-white"
  def tag_color_classes("pink"), do: "bg-pink-500 text-white"
  def tag_color_classes("rose"), do: "bg-rose-500 text-white"
  def tag_color_classes("slate"), do: "bg-slate-500 text-white"
  def tag_color_classes("stone"), do: "bg-stone-500 text-white"
  def tag_color_classes("primary"), do: "bg-primary text-primary-content"
  def tag_color_classes("secondary"), do: "bg-secondary text-secondary-content"
  def tag_color_classes("accent"), do: "bg-accent text-accent-content"
  def tag_color_classes("info"), do: "bg-info text-info-content"
  def tag_color_classes("success"), do: "bg-success text-success-content"
  def tag_color_classes("warning"), do: "bg-warning text-warning-content"
  def tag_color_classes("error"), do: "bg-error text-error-content"
  def tag_color_classes(_), do: "bg-base-300 text-base-content"
end
