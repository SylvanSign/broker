defmodule Broker.Bot do
  use Nostrum.Consumer

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    {dev_channel_id, ""} =
      "DEV_CHANNEL_ID"
      |> System.get_env()
      |> Integer.parse()

    if Mix.env() == :dev do
      if msg.channel_id == dev_channel_id do
        Broker.Bot.Command.reply(msg.content, msg)
      else
        :ignore
      end
    else
      if msg.channel_id == dev_channel_id do
        :ignore
      else
        Broker.Bot.Command.reply(msg.content, msg)
      end
    end
  end

  def handle_event(_event) do
    :noop
  end
end
