defmodule Memento.Capture.Feed do
  @behaviour :gen_statem

  @retry_interval 5000
  @refresh_interval 1000 * 60 * 5

  alias Memento.{Repo, Schema.Entry}

  require Logger

  def child_spec(handler) do
    %{
      id: {__MODULE__, handler},
      start: {__MODULE__, :start_link, [handler]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def callback_mode, do: :state_functions

  def start_link(handler) do
    start_link(handler, handler)
  end

  def start_link(handler, name) do
    start_link(handler.initial_data(), handler, name)
  end

  def start_link(initial_data, handler, name) do
    :gen_statem.start_link(
      {:local, name},
      __MODULE__,
      {initial_data, handler},
      []
    )
  end

  def refresh(worker) do
    :gen_statem.call(worker, :refresh)
  end

  def init({initial_data, handler}) do
    action = {:next_event, :internal, :authorize}
    {:ok, :idle, {initial_data, handler}, action}
  end

  def idle(:internal, :authorize, {data, handler}) do
    case handler.authorize(data) do
      {:ok, new_data} ->
        action = {:next_event, :internal, :refresh}
        {:next_state, :authorized, {new_data, handler}, action}

      {:error, reason} ->
        Logger.error(fn ->
          """
          Error authorizing #{inspect(handler)}.

          Reason: #{inspect(reason)}
          """
        end)

        {:stop, reason}
    end
  end

  def authorized(event_type, :refresh, {data, handler})
      when event_type in [:internal, :timeout] do
    case handler.refresh(data) do
      {:ok, new_entries_data, new_data} ->
        {new_count, _} = insert_all(new_entries_data, handler)

        Logger.info(fn ->
          """
          Refreshed #{inspect(handler)}, added #{new_count} new entries.
          """
        end)

        action = {:timeout, @refresh_interval, :refresh}
        {:keep_state, {new_data, handler}, action}

      {:error, reason} ->
        Logger.error(fn ->
          """
          Error refreshing #{inspect(handler)}.

          Reason: #{inspect(reason)}
          """
        end)

        action = {:timeout, @retry_interval, :refresh}
        {:keep_state, {data, handler}, action}
    end
  end

  def authorized({:call, from}, :refresh, {data, handler}) do
    case handler.refresh(data) do
      {:ok, new_entries_data, new_data} ->
        {new_count, _} = insert_all(new_entries_data, handler)

        Logger.info(fn ->
          """
          Refreshed #{inspect(handler)}, added #{new_count} new entries.
          """
        end)

        action = {:reply, from, {:ok, new_count}}
        {:keep_state, {new_data, handler}, action}

      {:error, reason} ->
        Logger.error(fn ->
          """
          Error refreshing #{inspect(handler)}.

          Reason: #{inspect(reason)}
          """
        end)

        action = {:reply, from, {:error, reason}}
        {:keep_state, {data, handler}, action}
    end
  end

  defp insert_all(new_entries_data, handler) do
    now = DateTime.utc_now()

    inserts =
      Enum.map(new_entries_data, fn new_entry_data ->
        [
          type: handler.entry_type(),
          content: new_entry_data,
          saved_at: handler.get_saved_at(new_entry_data),
          inserted_at: now,
          updated_at: now
        ]
      end)

    Repo.insert_all(Entry, inserts, on_conflict: :nothing)
  end
end
