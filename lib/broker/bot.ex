defmodule Broker.Bot do
  use Nostrum.Consumer

  @dev_channel_id 588_902_110_545_051_650

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    if Mix.env() == :dev do
      if msg.channel_id == @dev_channel_id do
        Broker.Bot.Command.reply(msg.content, msg)
      else
        :ignore
      end
    else
      if msg.channel_id == @dev_channel_id do
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
