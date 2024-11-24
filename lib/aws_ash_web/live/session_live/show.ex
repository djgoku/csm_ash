defmodule AwsAshWeb.SessionLive.Show do
  use AwsAshWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Session <%= @session.id %>
      <:subtitle>This is a session record from your database.</:subtitle>

      <:actions>
        <.link patch={~p"/sessions/#{@session}/show/edit"} phx-click={JS.push_focus()}>
          <.button>Edit session</.button>
        </.link>
      </:actions>
    </.header>

    <.list>
      <:item title="Id"><%= @session.id %></:item>

      <:item title="In port"><%= @session.in_port %></:item>

      <:item title="Client"><%= @session.client_id %></:item>
    </.list>

    <.table id="events-#{@session.id}" rows={@session.events}>
      <:col :let={event} label="Id"><%= event.id %></:col>

      <:col :let={event} label="Service"><%= event.service %></:col>

      <:col :let={event} label="Api"><%= event.api %></:col>

      <:col :let={event} label="Region"><%= event.json["Region"] %></:col>

      <:col :let={event} label="Inserted At">
        <%= event.inserted_at |> AwsAsh.to_local_datetime() %>
      </:col>
    </.table>

    <.back navigate={~p"/sessions"}>Back to sessions</.back>

    <.modal
      :if={@live_action == :edit}
      id="session-modal"
      show
      on_cancel={JS.patch(~p"/sessions/#{@session}")}
    >
      <.live_component
        module={AwsAshWeb.SessionLive.FormComponent}
        id={@session.id}
        title={@page_title}
        action={@live_action}
        session={@session}
        patch={~p"/sessions/#{@session}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:session, Ash.get!(AwsAsh.SdkMetrics.Session, id) |> Ash.load!(:events))}
  end

  defp page_title(:show), do: "Show Session"
  defp page_title(:edit), do: "Edit Session"
end
