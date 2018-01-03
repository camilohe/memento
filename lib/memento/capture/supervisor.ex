defmodule Memento.Capture.Supervisor do
  use Supervisor

  alias Memento.Capture.{Feed, Github, Instapaper, Pinboard, Status, Twitter}

  @refresh_interval 1000 * 60 * 5
  @retry_interval 5000
  @workers [
    Twitter.Handler,
    Github.Handler,
    Pinboard.Handler,
    Instapaper.Handler
  ]

  def start_link(env) do
    Supervisor.start_link(__MODULE__, env, name: __MODULE__)
  end

  def refresh_all do
    @workers
    |> Enum.map(fn w ->
         Task.async(Feed, :refresh, [w])
       end)
    |> Enum.map(&Task.await/1)
  end

  def init(env) do
    feed_workers = feed_workers(env)

    children = [Status] ++ feed_workers

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp feed_workers(:test), do: []

  defp feed_workers(_env) do
    Enum.map(@workers, fn w ->
      {Feed, worker_config(w)}
    end)
  end

  defp worker_config(handler) do
    %{
      handler: handler,
      name: handler,
      data: handler.initial_data(),
      status: Status,
      refresh_interval: @refresh_interval,
      retry_interval: @retry_interval
    }
  end
end
