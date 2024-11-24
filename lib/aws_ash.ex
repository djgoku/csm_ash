defmodule AwsAsh do
  @moduledoc """
  AwsAsh keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def to_local_datetime(datetime) do
    datetime
    |> Timex.to_datetime(Timex.Timezone.local())
    |> Timex.format!("{YYYY}-{M}-{D} {h24}:{m}")
  end
end
