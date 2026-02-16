defmodule Recommendations.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "3008")
    redis_url = System.get_env("REDIS_URL") || "redis://localhost:6379"

    children = [
      {Plug.Cowboy, scheme: :http, plug: Recommendations.Router, options: [port: port]},
      {Redix, {redis_url, [name: :redix]}}
    ]

    opts = [strategy: :one_for_one, name: Recommendations.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
