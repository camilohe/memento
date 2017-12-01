defmodule Memento.Capture.Twitter.Feed do
  use GenServer

  require Logger

  alias Memento.Capture.Twitter.{Client, Fav}

  def start_link({consumer_key, consumer_secret, name}) do
    GenServer.start_link(__MODULE__, {consumer_key, consumer_secret}, name: name)
  end

  def start_link(consumer_key, consumer_secret) do
    GenServer.start_link(__MODULE__, {consumer_key, consumer_secret})
  end

  def init({consumer_key, consumer_secret}) do
    send(self(), {:get_token, consumer_key, consumer_secret})
    {:ok, :no_token}
  end

  def handle_info({:get_token, consumer_key, consumer_secret}, _maybe_token) do
    case Client.get_token(consumer_key, consumer_secret) do
      {:ok, resp} ->
        send(self(), :get_favs)
        {:noreply, Map.get(resp, "access_token")}

      _error ->
        Logger.error(fn ->
          """
          Cannot fetch valid token with supplied Twitter credentials.

          Retrying in 5 seconds...
          """
        end)

        Process.send_after(self(), {:get_token, consumer_key, consumer_secret}, 5000)
        {:noreply, :no_token}
    end
  end

  def handle_info(:get_favs, token) do
    case Client.get_favs(token, "cloud8421", nil) do
      {:ok, resp} ->
        resp
        |> Enum.map(&Fav.content_from_api_result/1)
        |> insert_all()

        Process.send_after(self(), {:get_favs, token}, 1000 * 300)

      error ->
        Logger.error(fn ->
          """
          Cannot fetch favs.

          Retrying in 5 seconds...
          """
        end)

        Process.send_after(self(), {:get_favs, token}, 5000)
    end

    {:noreply, token}
  end

  defp insert_all(favs) do
    now = DateTime.utc_now()

    inserts =
      Enum.map(favs, fn fav ->
        [
          id: fav.id,
          type: :twitter_fav,
          content: fav,
          saved_at: fav.created_at,
          inserted_at: now,
          updated_at: now
        ]
      end)

    Memento.Repo.insert_all(Memento.Schema.Entry, inserts)
  end
end
