defmodule AwsAsh.SdkMetrics.Server do
  use GenServer
  require Logger
  require Ash.Query

  alias AwsAsh.SdkMetrics.Session

  # Client

  def start_link([]), do: start_link(udp_port: 31000, number_of_sessions_to_track: 10)

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: AwsAsh.SdkMetrics.Server)
  end

  # Server

  @impl true
  def init(udp_port: udp_port, number_of_sessions_to_track: number_of_sessions_to_track) do
    sessions =
      Session
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(number_of_sessions_to_track)
      |> Ash.Query.filter(inserted_at >= today())
      |> Ash.read!()

    Logger.info("#{__MODULE__} listening on udp port #{udp_port}")
    {:ok, _socket} = :gen_udp.open(31000)

    {:ok, %{sessions: sessions}}
  end

  @impl true
  def handle_info({:udp, _port, _ip, in_port, message}, state) do
    json = Jason.decode!(message)

    state =
      case maybe_existing_session(state, in_port, json) do
        [] ->
          session = AwsAsh.SdkMetrics.session!(in_port, json["ClientId"])

          create_event(json, session)

          %{state | sessions: [session] ++ state.sessions}

        [session] ->
          event = create_event(json, session)
          state
      end

    {:noreply, state}
  end

  @doc """
  Search for an existing session and return it, else return an empty list.

  There is a possibility that a session(s) has the same in_port (since
  we use this as part of uniqueness), so we will just return the first occurence.
  """
  def maybe_existing_session(state, in_port, json) do
    result =
      state.sessions
      |> Enum.filter(fn s ->
        s.in_port == in_port && s.client_id == json["ClientId"]
      end)

    if Enum.count(result) > 1 do
      List.first(result)
    else
      result
    end
  end

  defp create_event(json, session) do
    AwsAsh.SdkMetrics.event!(
      json["Api"],
      json["ClientId"],
      json["Service"],
      json,
      session.id
    )
  end
end
