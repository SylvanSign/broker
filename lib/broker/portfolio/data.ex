require Logger

defmodule Broker.Portfolio.Data do
  use Agent
  alias Broker.Portfolio.Trader

  @name __MODULE__

  ##############
  # PUBLIC API #
  ##############
  def start_link([]) do
    Agent.start_link(fn ->
      {:ok, @name} = Util.PersistentCache.load(@name)
      :ok
    end)
  end

  def fetch_trader(id) do
    case Util.PersistentCache.get(@name, id) do
      nil ->
        new_trader = %Trader{id: id}
        Util.PersistentCache.put(@name, id, new_trader)
        new_trader

      trader_info ->
        trader_info
    end
  end

  def all_traders do
    Util.PersistentCache.all(@name)
  end

  def store_trader(id, trader) do
    Util.PersistentCache.put(@name, id, trader)
  end

  def trade(id, ticker, shares) do
    trader = Broker.Portfolio.Data.fetch_trader(id)
    {:ok, updated_trader} = Broker.Portfolio.Trader.trade(trader, ticker, shares)
    store_trader(id, updated_trader)

    {:ok, updated_trader}
  end
end
