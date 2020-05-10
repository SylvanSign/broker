defmodule Broker.Report.Scheduler do
  use Quantum, otp_app: :broker

  @investor_channel_id 686_660_042_208_182_397

  def report(title) do
    Nostrum.Api.create_message(
      @investor_channel_id,
      "```\n#{Broker.Bot.Command.report_message(title)}\n```"
    )
  end

  def trading_open_alert do
    Nostrum.Api.create_message(
      @investor_channel_id,
      """
      Trading is OPEN, boys! Try not to get too bogged...
      """
    )
  end

  def trading_close_alert do
    Nostrum.Api.create_message(
      @investor_channel_id,
      """
      Trading is CLOSED, boys!

      If you send me trades now, I'll queue them up for the next market open.
      """
    )
  end
end
