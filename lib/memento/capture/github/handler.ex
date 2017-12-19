defmodule Memento.Capture.Github.Handler do
  @behaviour Memento.Capture.Handler

  alias Memento.Capture.Github.{Client, StarredRepo}

  def entry_type, do: :github_star

  def get_saved_at(content), do: content.starred_at

  def initial_data do
    %{username: "cloud8421"}
  end

  def authorize(data) do
    {:ok, data}
  end

  def refresh(data) do
    case Client.get_stars_by_username(data.username) do
      {:ok, resp, _} ->
        {:ok, Enum.map(resp, &StarredRepo.content_from_api_result/1), data}

      error ->
        error
    end
  end
end
