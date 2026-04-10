defmodule ExClawWeb.PageControllerTest do
  use ExClawWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end

  test "GET / redirects authenticated users to /assistant", %{conn: conn} do
    conn = conn |> log_in_user(ExClaw.AccountsFixtures.user_fixture()) |> get(~p"/")

    assert redirected_to(conn) == ~p"/assistant"
  end
end
