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
      rows={@page.results}
      row_click={fn session -> JS.navigate(~p"/#{session.id}?#{@query_map}") end}
    >
      <:col :let={session} label="Id">{session.id}</:col>

      <:col :let={session} label="In port">{session.in_port}</:col>

      <:col :let={session} label="Client">{session.client_id}</:col>

      <:col :let={session} label="Inserted At (Local time)">
        {AwsAsh.to_local_datetime(session.inserted_at)}
      </:col>
    </.table>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    AwsAshWeb.Endpoint.subscribe("sessions")

    page =
      AwsAsh.SdkMetrics.Session
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!(page: [count: true])

    {:ok, socket |> assign(:inserted, false) |> assign(:page, page)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = Map.get(params, "q", "")
    page_params = AshPhoenix.LiveView.page_from_params(params, 15)
    page_params = Keyword.put(page_params, :count, true)

    page =
      if String.length(query) > 0 do
        offset = AwsAsh.SdkMetrics.search!("%#{query}%")
        session_ids = offset |> Enum.map(& &1.session_id)

        AwsAsh.SdkMetrics.Session
        |> Ash.Query.filter(id in ^session_ids)
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!(page: page_params)
      else
        AwsAsh.SdkMetrics.Session
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!(page: page_params)
      end

    {:noreply,
     apply_action(socket, socket.assigns.live_action, params)
     |> assign(:query, query)
     |> assign(:query_map, params)
     |> assign(:page, page)}
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
    page = socket.assigns.page
    page = Map.put(page, :results, [payload] ++ page.results)
    {:noreply, socket |> assign(:inserted, true) |> assign(:page, page)}
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
