defmodule AwsAsh.SdkMetrics.Event do
  require Logger
  use Ash.Resource, otp_app: :aws_ash, domain: AwsAsh.SdkMetrics, data_layer: AshSqlite.DataLayer

  require Ash.Query

  sqlite do
    table "events"
    repo AwsAsh.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:api, :client_id, :service, :type, :json, :session_id]
    end

    read :get_events_by_session_id do
      argument :session_id, :string
      filter expr(session_id == ^arg(:session_id))

      pagination do
        offset? true
        countable true
      end
    end

    read :search do
      argument :query, :string do
        constraints allow_empty?: true
        default ""
      end

      # Only return ApiCall as these were successful API calls.
      #
      # ilike is used since we want case-insensitive searching and
      # ash_sqlite like is case-sensitive.
      filter expr(
               type != "" and type == "ApiCall" and ilike(combine_service_and_api, ^arg(:query))
             )

      prepare build(load: [:combine_service_and_api])

      # after_action runs so only unique sessions are returned since
      # we can have the same API call happening multiple times within
      # a session.
      prepare after_action(fn query, records, _context ->
                Logger.debug(
                  "Query for #{query.action.name} on resource #{inspect(query.resource)} returned #{length(records)} records"
                )

                {:ok, Enum.uniq_by(records, & &1.session_id)}
              end)
    end
  end

  preparations do
    prepare build(sort: [inserted_at: :desc])
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
    update_timestamp :updated_at

    attribute :api, :string do
      allow_nil? false
      public? true
    end

    attribute :client_id, :string do
      allow_nil? false
      public? true
    end

    attribute :service, :string do
      allow_nil? false
      public? true
    end

    attribute :type, :string do
      allow_nil? false
      public? true
    end

    attribute :json, :map do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :session, AwsAsh.SdkMetrics.Session
  end

  calculations do
    calculate :combine_service_and_api, :string, expr(string_downcase(service) <> ":" <> api)
  end

  def unique_events(events) do
    events
    |> Enum.map(& &1.combine_service_and_api)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
