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
      case state.sessions
           |> Enum.filter(fn s -> s.in_port == in_port && s.client_id == json["ClientId"] end) do
        [] ->
          session = AwsAsh.SdkMetrics.session!(in_port, json["ClientId"])

          AwsAsh.SdkMetrics.event!(
            json["Api"],
            json["ClientId"],
            json["Service"],
            json,
            session.id
          )

          %{state | sessions: [session] ++ state.sessions}

        [match] ->
          AwsAsh.SdkMetrics.event!(json["Api"], json["ClientId"], json["Service"], json, match.id)
          state
      end

    {:noreply, state}
  end
end
