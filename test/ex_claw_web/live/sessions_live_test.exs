defmodule ExClawWeb.SessionsLiveTest do
  use ExClawWeb.ConnCase

  import Phoenix.LiveViewTest
  import ExClaw.AccountsFixtures, only: [user_scope_fixture: 0]
  import ExClaw.AssistantFixtures

  alias ExClaw.Assistant

  describe "/assistant/sessions" do
    test "redirects unauthenticated users to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/assistant/sessions")

      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "/assistant/sessions for authenticated users" do
    setup :register_and_log_in_user

    test "redirects to the latest non-archived session", %{conn: conn, scope: scope} do
      _archived_session =
        assistant_session_fixture(scope, %{
          title: "Archived",
          archived_at: DateTime.utc_now(:second)
        })

      session = assistant_session_fixture(scope, %{title: "Latest active"})

      assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/assistant/sessions")
      assert path == ~p"/assistant/sessions/#{session.id}"
    end

    test "creates a session when the user has no active sessions", %{conn: conn, scope: scope} do
      _archived_session =
        assistant_session_fixture(scope, %{
          title: "Archived",
          archived_at: DateTime.utc_now(:second)
        })

      assert [] == Assistant.list_sessions(scope)

      assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/assistant/sessions")

      [session] = Assistant.list_sessions(scope)
      assert path == ~p"/assistant/sessions/#{session.id}"
    end
  end

  describe "/assistant/sessions/:session_id" do
    setup :register_and_log_in_user

    test "renders the requested owned session shell", %{conn: conn, scope: scope} do
      session = assistant_session_fixture(scope, %{title: "Session Alpha"})
      _message = assistant_message_fixture(session, %{content: "Hello from the transcript"})

      {:ok, view, _html} = live(conn, ~p"/assistant/sessions/#{session.id}")

      assert has_element?(view, "#assistant-session-shell")
      assert has_element?(view, "#assistant-session-title", session.title)
      assert has_element?(view, "#assistant-sessions")
      assert has_element?(view, "#assistant-transcript")
      assert has_element?(view, "#assistant-composer")
      refute has_element?(view, "#assistant-archived-notice")
    end

    test "renders archived sessions in read-only mode", %{conn: conn, scope: scope} do
      session =
        assistant_session_fixture(scope, %{
          title: "Archived session",
          archived_at: DateTime.utc_now(:second)
        })

      {:ok, view, _html} = live(conn, ~p"/assistant/sessions/#{session.id}")

      assert has_element?(view, "#assistant-session-title", session.title)
      assert has_element?(view, "#assistant-archived-notice", "This session is archived.")
      assert has_element?(view, "#assistant-composer-input[disabled]")
      assert has_element?(view, "#assistant-composer-submit[disabled]")
    end

    test "redirects when the requested session does not belong to the current user", %{
      conn: conn
    } do
      other_session =
        assistant_session_fixture(user_scope_fixture(), %{title: "Other user's session"})

      assert {:error, {:live_redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/assistant/sessions/#{other_session.id}")

      assert path == ~p"/assistant/sessions"

      assert Enum.any?(Map.values(flash), fn message ->
               String.contains?(message, "unavailable")
             end)
    end

    test "redirects when the requested session does not exist", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/assistant/sessions/-1")

      assert path == ~p"/assistant/sessions"

      assert Enum.any?(Map.values(flash), fn message ->
               String.contains?(message, "unavailable")
             end)
    end
  end
end
