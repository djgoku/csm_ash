defmodule AwsAsh.SdkMetrics.Event do
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

    update :assign do
      accept [:session_id]
    end
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
