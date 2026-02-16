defmodule Recommendations.Router do
  use Plug.Router

  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  get "/health" do
    send_json(conn, 200, %{status: "ok", service: "recommendations"})
  end

  get "/recommendations/:user_id" do
    case Redix.command(:redix, ["GET", "recs:#{user_id}"]) do
      {:ok, nil} ->
        # Generate default recommendations
        defaults = [
          %{product_id: 1, score: 0.95, reason: "popular"},
          %{product_id: 5, score: 0.87, reason: "trending"},
          %{product_id: 12, score: 0.82, reason: "similar_users"}
        ]
        Redix.command(:redix, ["SETEX", "recs:#{user_id}", "3600", Jason.encode!(defaults)])
        send_json(conn, 200, defaults)

      {:ok, cached} ->
        send_json(conn, 200, Jason.decode!(cached))

      {:error, reason} ->
        send_json(conn, 500, %{error: inspect(reason)})
    end
  end

  post "/recommendations/refresh" do
    user_id = conn.body_params["user_id"]
    Redix.command(:redix, ["DEL", "recs:#{user_id}"])
    send_json(conn, 200, %{refreshed: true, user_id: user_id})
  end

  match _ do
    send_json(conn, 404, %{error: "not found"})
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end
end
