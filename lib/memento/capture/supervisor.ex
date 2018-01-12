defmodule Memento.Capture.Supervisor do
  use Supervisor

  alias Memento.Capture.{Feed, Status}

  @refresh_interval 1000 * 60 * 5
  @retry_interval 5000
  @enabled_handlers Application.get_env(:memento, :enabled_handlers, [])

  def start_link(env) do
    Supervisor.start_link(__MODULE__, env, name: __MODULE__)
  end

  def refresh_all do
    @enabled_handlers
    |> Enum.map(fn w ->
         Task.async(Feed, :refresh, [w])
       end)
    |> Enum.map(&Task.await/1)
  end

  def init(_env) do
    feed_workers =
      Enum.map(@enabled_handlers, fn w ->
        {Feed, worker_config(w)}
      end)

    children = [Status] ++ feed_workers

    Supervisor.init(children, strategy: :one_for_one)
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
