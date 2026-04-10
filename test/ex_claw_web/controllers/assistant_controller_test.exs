defmodule ExClawWeb.AssistantControllerTest do
  use ExClawWeb.ConnCase

  describe "GET /assistant" do
    test "redirects unauthenticated users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/assistant")

      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects authenticated users to /assistant/sessions", %{conn: conn} do
      conn = conn |> log_in_user(ExClaw.AccountsFixtures.user_fixture()) |> get(~p"/assistant")

      assert redirected_to(conn) == ~p"/assistant/sessions"
    end
  end
end
