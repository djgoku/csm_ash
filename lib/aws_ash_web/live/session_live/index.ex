defmodule AwsAshWeb.SessionLive.Index do
  use AwsAshWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Sessions
      <:actions></:actions>
    </.header>

    <.table
      id="sessions"
      rows={@streams.sessions}
      row_click={fn {_id, session} -> JS.navigate(~p"/sessions/#{session}") end}
    >
      <:col :let={{_id, session}} label="Id"><%= session.id %></:col>

      <:col :let={{_id, session}} label="In port"><%= session.in_port %></:col>

      <:col :let={{_id, session}} label="Client"><%= session.client_id %></:col>

      <:col :let={{_id, session}} label="Inserted At (Local time)">
        <%= AwsAsh.to_local_datetime(session.inserted_at) %>
      </:col>

      <:action :let={{_id, session}}>
        <div class="sr-only">
          <.link navigate={~p"/sessions/#{session}"}>Show</.link>
        </div>

        <.link patch={~p"/sessions/#{session}/edit"}>Edit</.link>
      </:action>
    </.table>

    <.modal :if={@live_action in [:edit]} id="session-modal" show on_cancel={JS.patch(~p"/sessions")}>
      <.live_component
        module={AwsAshWeb.SessionLive.FormComponent}
        id={@session && @session.id}
        title={@page_title}
        action={@live_action}
        session={@session}
        patch={~p"/sessions"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    sessions =
      AwsAsh.SdkMetrics.Session
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!()

    {:ok, stream(socket, :sessions, sessions)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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
end
