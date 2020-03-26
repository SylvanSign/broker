require Logger

defmodule Broker.Portfolio.Data do
  use Agent
  alias Broker.Portfolio.Trader

  @name __MODULE__

  ##############
  # PUBLIC API #
  ##############
  def start_link([]) do
    Agent.start_link(
      fn ->
        {:ok, @name} = Util.PersistentCache.load(@name)
        :ok
      end,
      name: @name
    )
  end

  def reset do
    Agent.get(@name, fn _ ->
      {:ok, @name} = Util.PersistentCache.reset(@name)
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

  def trade_by_shares(id, ticker, shares) do
    trade(&Broker.Portfolio.Trader.trade_by_shares/3, id, ticker, shares)
  end

  def trade_by_value(id, ticker, value) do
    trade(&Broker.Portfolio.Trader.trade_by_value/3, id, ticker, value)
  end

  defp trade(trade_function, id, ticker, amount) do
    trader = Broker.Portfolio.Data.fetch_trader(id)

    with {:ok, updated_trader} <- trade_function.(trader, ticker, amount) do
      store_trader(id, updated_trader)
      {:ok, updated_trader}
    end
  end
end
