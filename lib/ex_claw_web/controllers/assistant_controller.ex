defmodule ExClawWeb.AssistantController do
  use ExClawWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: ~p"/assistant/sessions")
  end
end
