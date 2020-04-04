defmodule Broker.Report.Scheduler do
  use Quantum, otp_app: :broker

  @investor_channel_id 686_660_042_208_182_397

  def report(title) do
    Nostrum.Api.create_message(
      @investor_channel_id,
      "```\n#{Broker.Bot.Command.report_message(title)}\n```"
    )
  end
end
