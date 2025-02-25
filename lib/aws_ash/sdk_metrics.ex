defmodule AwsAsh.SdkMetrics do
  use Ash.Domain

  resources do
    resource AwsAsh.SdkMetrics.Session do
      define :session, args: [:in_port, :client_id], action: :create
      define :get_session_by_id, action: :read, get_by: :id
    end

    resource AwsAsh.SdkMetrics.Event do
      define :event,
        args: [:api, :client_id, :service, :type, :json, :session_id],
        action: :create

    end
  end
end
