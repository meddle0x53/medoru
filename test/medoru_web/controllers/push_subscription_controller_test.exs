defmodule MedoruWeb.PushSubscriptionControllerTest do
  use MedoruWeb.ConnCase

  import Medoru.AccountsFixtures

  describe "POST /api/push-subscribe" do
    test "requires authentication", %{conn: conn} do
      conn = post(conn, ~p"/api/push-subscribe", %{subscription: %{}})
      assert redirected_to(conn) == ~p"/"
    end

    test "stores push subscription for authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      payload = %{
        subscription: %{
          endpoint: "https://fcm.googleapis.com/fcm/send/test-123",
          keys: %{
            p256dh:
              "BLxuja-129dN_6pVsAeAABXiRkPtOogAmAuM2pomg7RquL_sflksWO4rDUnngBF6xG26ZEiTMFkBc-p7h68MwOs",
            auth: "HIGtxCi2gwAzBI2hjdZWHkPwnHHtWfv3RjKqmC6ovI0"
          }
        }
      }

      conn = post(conn, ~p"/api/push-subscribe", payload)
      assert json_response(conn, 200)["status"] == "subscribed"

      # Verify it was stored
      subs = Medoru.Notifications.list_push_subscriptions(user.id)
      assert length(subs) == 1
      assert hd(subs).endpoint == "https://fcm.googleapis.com/fcm/send/test-123"
    end
  end

  describe "DELETE /api/push-subscribe" do
    test "removes push subscription", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # First create a subscription
      Medoru.Notifications.create_or_update_push_subscription(user.id, %{
        "endpoint" => "https://fcm.googleapis.com/fcm/send/test-delete",
        "keys" => %{
          "p256dh" =>
            "BLxuja-129dN_6pVsAeAABXiRkPtOogAmAuM2pomg7RquL_sflksWO4rDUnngBF6xG26ZEiTMFkBc-p7h68MwOs",
          "auth" => "HIGtxCi2gwAzBI2hjdZWHkPwnHHtWfv3RjKqmC6ovI0"
        }
      })

      assert length(Medoru.Notifications.list_push_subscriptions(user.id)) == 1

      conn =
        delete(conn, ~p"/api/push-subscribe", %{
          endpoint: "https://fcm.googleapis.com/fcm/send/test-delete"
        })

      assert json_response(conn, 200)["status"] == "unsubscribed"

      assert Medoru.Notifications.list_push_subscriptions(user.id) == []
    end
  end
end
