defmodule Broker.Portfolio.Database do
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

  def store_trader(%Trader{id: id} = trader) do
    Util.PersistentCache.put(@name, id, trader)
    trader
  end

  def trade_by_shares(id, ticker, shares) do
    trade(&Broker.Portfolio.Trader.trade_by_shares/3, id, ticker, shares)
  end

  def trade_by_value(id, ticker, value) do
    trade(&Broker.Portfolio.Trader.trade_by_value/3, id, ticker, value)
  end

  # the `correct_*` functions are for manual overriding things that are hard to automate, like stock
  # splits & reverse splits
  def correct_shares(id, ticker, shares) do
    trader = Broker.Portfolio.Database.fetch_trader(id)

    %{trader | holdings: Map.put(trader.holdings, ticker, shares)}
    |> store_trader()
  end

  def correct_cash(id, cash) do
    trader = Broker.Portfolio.Database.fetch_trader(id)

    %{trader | cash: Float.round(cash / 1, 2)}
    |> store_trader()
  end

  defp trade(trade_function, id, ticker, amount) do
    trader = Broker.Portfolio.Database.fetch_trader(id)

    with {:ok, updated_trader} <- trade_function.(trader, ticker, amount) do
      store_trader(updated_trader)
      {:ok, updated_trader}
    end
  end
end
