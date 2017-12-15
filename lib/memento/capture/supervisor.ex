defmodule Memento.Capture.Supervisor do
  use Supervisor

  alias Memento.Capture.{Github, Instapaper, Pinboard, Twitter}

  def start_link(env) do
    Supervisor.start_link(__MODULE__, env, name: __MODULE__)
  end

  def init(env) do
    Supervisor.init(children(env), strategy: :one_for_one)
  end

  defp children(:test), do: []

  defp children(_env) do
    twitter_feed_start_args =
      {
        System.get_env("TWITTER_CONSUMER_KEY"),
        System.get_env("TWITTER_CONSUMER_SECRET"),
        Twitter.Feed
      }

    pinboard_feed_start_args =
      {System.get_env("PINBOARD_API_TOKEN"), Pinboard.Feed}

    instapaper_creds = Instapaper.Creds.get_from_env()

    instapaper_feed_start_args = {
      instapaper_creds.consumer_key,
      instapaper_creds.consumer_secret,
      instapaper_creds.username,
      instapaper_creds.password,
      Instapaper.Feed
    }

    [
      {Twitter.Feed, twitter_feed_start_args},
      {Github.Feed, Github.Feed},
      {Instapaper.Feed, instapaper_feed_start_args},
      {Pinboard.Feed, pinboard_feed_start_args}
    ]
  end
end
