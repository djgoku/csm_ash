defmodule AwsAshWeb.SessionLive.Show do
  use AwsAshWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Session {@session.id}
      <:subtitle>This is a session record from your database.</:subtitle>

      <:actions>
        <.link patch={~p"/#{@session}/show/edit"} phx-click={JS.push_focus()}>
          <.button>Edit session</.button>
        </.link>
      </:actions>
    </.header>

    <.list>
      <:item title="Id">{@session.id}</:item>

      <:item title="In port">{@session.in_port}</:item>

      <:item title="Client">{@session.client_id}</:item>
    </.list>

    <.input
      id="iam-policy"
      type="textarea"
      label="iam-policy"
      name="iam-policy"
      value={@iam_policy}
      readonly
      rows={@iam_policy_lines}
    />

    <button
      phx-click={JS.dispatch("session_live:copy_iam_policy_to_clipboard", to: "#iam-policy")}
      class="text-black dark:text-white"
    >
      Copy IAM policy to clipboard
    </button>

    <.table id="events-#{@session.id}" rows={@session.events}>
      <:col :let={event} label="Id">{event.id}</:col>

      <:col :let={event} label="Service">{event.service}</:col>

      <:col :let={event} label="Api">{event.api}</:col>

      <:col :let={event} label="Region">{event.json["Region"]}</:col>

      <:col :let={event} label="Inserted At">
        {event.inserted_at |> AwsAsh.to_local_datetime()}
      </:col>
    </.table>

    <.back navigate={~p"/"}>Back to sessions</.back>

    <.modal :if={@live_action == :edit} id="session-modal" show on_cancel={JS.patch(~p"/#{@session}")}>
      <.live_component
        module={AwsAshWeb.SessionLive.FormComponent}
        id={@session.id}
        title={@page_title}
        action={@live_action}
        session={@session}
        patch={~p"/#{@session}"}
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
    session = AwsAsh.SdkMetrics.get_session_by_id!(id, load: [events: [:combine_service_and_api]])

    iam_policy_json_string =
      AwsAsh.iam_policy_json_string(AwsAsh.SdkMetrics.Event.unique_events(session.events))

    iam_policy_lines = AwsAsh.iam_policy_json_string_lines(iam_policy_json_string)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:session, session)
     |> assign(:iam_policy, iam_policy_json_string)
     |> assign(:iam_policy_lines, iam_policy_lines)}
  end

  defp page_title(:show), do: "Show Session"
  defp page_title(:edit), do: "Edit Session"
end
