defmodule AwsAsh.SdkMetrics.Session do
  use Ash.Resource, otp_app: :aws_ash, domain: AwsAsh.SdkMetrics, data_layer: AshSqlite.DataLayer

  sqlite do
    table "sessions"
    repo AwsAsh.Repo
  end

  actions do
    read :read do
      primary? true

      pagination do
        offset? true
        default_limit 15
        countable true
      end
    end

    create :create do
      accept [:in_port, :client_id]
      primary? true
    end

    update :update do
      accept :client_id
      primary? true
    end
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
    update_timestamp :updated_at

    attribute :in_port, :integer do
      allow_nil? false
      public? true
    end

    attribute :client_id, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    has_many :events, AwsAsh.SdkMetrics.Event
  end
end
