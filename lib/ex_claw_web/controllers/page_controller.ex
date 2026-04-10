defmodule ExClawWeb.PageController do
  use ExClawWeb, :controller

  def home(conn, _params) do
    current_scope = conn.assigns[:current_scope]

    if current_scope && current_scope.user do
      redirect(conn, to: ~p"/assistant")
    else
      render(conn, :home)
    end
  end
end
