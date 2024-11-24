defmodule AwsAsh.SdkMetrics do
  use Ash.Domain

  resources do
    resource AwsAsh.SdkMetrics.Session do
      define :session, args: [:in_port, :client_id], action: :create
    end

    resource AwsAsh.SdkMetrics.Event do
      define :event, args: [:api, :client_id, :service, :json, :session_id], action: :create
    end
  end
end
