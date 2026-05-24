defmodule MedoruWeb.Presence do
  @moduledoc """
  Provides presence tracking for online users and chat participants.
  """
  use Phoenix.Presence,
    otp_app: :medoru,
    pubsub_server: Medoru.PubSub
end
