defmodule AwsAshWeb.SessionLive.Show do
  use AwsAshWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Session {@session.id}
      <:subtitle>This is a session record from your database.</:subtitle>
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

    <.table id="events-totals-#{@session.id}" rows={@totals_for_combine_service_and_api}>
      <:col :let={event} label="Name">{event.name}</:col>
      <:col :let={event} label="Attempt">{event.api_call_attempt}</:col>
      <:col :let={event} label="Success">{event.api_call}</:col>
      <:col :let={event} label="Percentage">{event.percentage_of_success}%</:col>
    </.table>

    <.table id="events-#{@session.id}" rows={@session.events}>
      <:col :let={event} label="Id">{event.id}</:col>

      <:col :let={event} label="Service">{event.service}</:col>

      <:col :let={event} label="Api">{event.api}</:col>

      <:col :let={event} label="Region">{event.json["Region"]}</:col>

      <:col :let={event} label="Type">{event.type}</:col>

      <:col :let={event} label="Inserted At">
        {event.inserted_at |> AwsAsh.to_local_datetime()}
      </:col>
    </.table>

    <.back navigate={~p"/?#{@query_map}"}>Back to sessions</.back>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    AwsAshWeb.Endpoint.subscribe("session:#{id}")
    session = AwsAsh.SdkMetrics.get_session_by_id!(id, load: [events: [:combine_service_and_api]])

    iam_policy_json_string =
      AwsAsh.iam_policy_json_string(AwsAsh.SdkMetrics.Event.unique_events(session.events))

    iam_policy_lines = AwsAsh.iam_policy_json_string_lines(iam_policy_json_string)

    totals_for_combine_service_and_api =
      calculate_totals_for_combine_service_and_api(session.events)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:session, session)
     |> assign(:iam_policy, iam_policy_json_string)
     |> assign(:iam_policy_lines, iam_policy_lines)
     |> assign(:totals_for_combine_service_and_api, totals_for_combine_service_and_api)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "session:" <> _session_id,
          event: "new-event",
          payload: payload
        },
        socket
      ) do
    payload = Ash.load!(payload, [:combine_service_and_api])
    events = [payload] ++ socket.assigns.session.events
    unique_events = AwsAsh.SdkMetrics.Event.unique_events(events)
    iam_policy_json_string = AwsAsh.iam_policy_json_string(unique_events)
    session = Map.put(socket.assigns.session, :events, events)

    socket =
      socket
      |> assign(:session, session)
      |> assign(:unique_events, unique_events)
      |> assign(:iam_policy, iam_policy_json_string)
      |> assign(:iam_policy_lines, AwsAsh.iam_policy_json_string_lines(iam_policy_json_string))

    {:noreply, socket}
  end

  def calculate_totals_for_combine_service_and_api(events) do
    events
    |> Enum.reduce(%{}, fn event, acc ->
      service_and_api_map =
        Map.get(acc, event.combine_service_and_api, %{
          name: event.combine_service_and_api,
          api_call_attempt: 0,
          api_call: 0,
          percentage_of_success: 0
        })

      service_and_api_map =
        case event.type do
          "ApiCall" ->
            %{service_and_api_map | api_call: service_and_api_map.api_call + 1}

          "ApiCallAttempt" ->
            %{service_and_api_map | api_call_attempt: service_and_api_map.api_call_attempt + 1}
        end

      Map.put(acc, event.combine_service_and_api, service_and_api_map)
    end)
    |> Enum.map(fn {_k, service_and_api_map} ->
      if service_and_api_map.api_call > 0 and service_and_api_map.api_call_attempt > 0 do
        %{
          service_and_api_map
          | percentage_of_success:
              floor(service_and_api_map.api_call / service_and_api_map.api_call_attempt * 100)
        }
      else
        service_and_api_map
      end
    end)
  end

  defp page_title(:show), do: "Show Session"
  defp page_title(:edit), do: "Edit Session"
end
