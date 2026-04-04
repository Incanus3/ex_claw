defmodule ExClawWeb.PageController do
  use ExClawWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
