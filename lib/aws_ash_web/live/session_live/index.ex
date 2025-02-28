defmodule AwsAshWeb.SessionLive.Index do
  use AwsAshWeb, :live_view

  require Ash.Query

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Sessions
      <:actions>
        <.simple_form :let={f} for={%{}} phx-submit="maybe_search_or_selected">
          <.input
            label="Search events"
            type="search"
            field={f[:query]}
            value={@query}
            placeholder="sts"
          />
        </.simple_form>
      </:actions>
    </.header>

    <.table
      id="sessions"
      rows={@streams.sessions}
      row_click={fn {_id, session} -> JS.navigate(~p"/#{session}") end}
    >
      <:col :let={{_id, session}} label="Id">{session.id}</:col>

      <:col :let={{_id, session}} label="In port">{session.in_port}</:col>

      <:col :let={{_id, session}} label="Client">{session.client_id}</:col>

      <:col :let={{_id, session}} label="Inserted At (Local time)">
        {AwsAsh.to_local_datetime(session.inserted_at)}
      </:col>

      <:action :let={{_id, session}}>
        <div class="sr-only">
          <.link navigate={~p"/#{session}"}>Show</.link>
        </div>
      </:action>
    </.table>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    AwsAshWeb.Endpoint.subscribe("sessions")

    sessions =
      AwsAsh.SdkMetrics.Session
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!()

    {:ok, socket |> assign(:inserted, false) |> stream(:sessions, sessions)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query_text = Map.get(params, "q", "")

    sessions =
      if String.length(query_text) > 0 do
        session_ids =
          AwsAsh.SdkMetrics.search!("%#{query_text}%") |> Enum.map(& &1.session_id)

        AwsAsh.SdkMetrics.Session |> Ash.Query.filter(id in ^session_ids) |> Ash.read!()
      else
        AwsAsh.SdkMetrics.Session
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!()
      end

    {:noreply,
     apply_action(socket, socket.assigns.live_action, params)
     |> assign(:query, query_text)
     |> stream(:sessions, sessions, reset: true)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Session")
    |> assign(:session, Ash.get!(AwsAsh.SdkMetrics.Session, id))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Sessions")
    |> assign(:session, nil)
  end

  @impl true
  def handle_info({AwsAshWeb.SessionLive.FormComponent, {:saved, session}}, socket) do
    {:noreply, stream_insert(socket, :sessions, session)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "sessions",
          event: "new-session",
          payload: payload
        },
        socket
      ) do
    {:noreply, socket |> assign(:inserted, true) |> stream_insert(:sessions, payload, at: 0)}
  end

  @impl true
  def handle_event("maybe_search_or_selected", %{"query" => query}, socket) do
    params = %{q: query} |> remove_empty()
    {:noreply, socket |> push_patch(to: ~p"/?#{params}")}
  end

  defp remove_empty(params) do
    Enum.filter(params, fn {_key, val} -> val != "" end)
  end
end
