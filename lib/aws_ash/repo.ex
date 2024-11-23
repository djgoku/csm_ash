defmodule AwsAsh.Repo do
  use AshSqlite.Repo,
    otp_app: :aws_ash
end
