defmodule Broker.Portfolio.Trader do
  alias Broker.Portfolio.Trader
  alias Broker.Portfolio.Orders
  alias Number.Currency
  alias TableRex.Table

  defstruct [:id, cash: 10_000, holdings: %{}, orders: %Orders{}]

  def update_orders(%Trader{orders: orders} = trader, func) do
    orders = func.(orders)
    %Trader{trader | orders: orders}
  end

  def update_cash(%Trader{cash: cash} = trader, cash_adjust, share_adjust, share_price) do
    balance = cash + cash_adjust

    if balance == 0 and balance < 0 do
      {:error, "you don't have any cash"}
    else
      if balance < 0 do
        share_adjust =
          (cash / share_price)
          |> floor

        balance = cash - share_adjust * share_price

        {:ok, %Trader{trader | cash: balance |> Float.round(2)}, share_adjust}
      else
        {:ok, %Trader{trader | cash: balance |> Float.round(2)}, share_adjust}
      end
    end
  end

  def update_holdings(
        %Trader{holdings: holdings} = trader,
        ticker,
        share_adjust,
        share_price
      ) do
    shares = Map.get(holdings, ticker, 0)
    balance = shares + share_adjust

    if shares == 0 and balance < 0 do
      {:error, "you don't have any #{ticker} shares"}
    else
      if balance < 0 do
        # sell as much as we can
        cash_adjust = shares * share_price

        {:ok, %Trader{trader | holdings: Map.delete(holdings, ticker)}, cash_adjust}
      else
        cash_adjust = -(share_adjust * share_price)

        if balance == 0 do
          updated_trader = %Trader{trader | holdings: Map.delete(holdings, ticker)}
          {:ok, updated_trader, cash_adjust}
        else
          updated_trader = %Trader{trader | holdings: Map.put(holdings, ticker, balance)}
          {:ok, updated_trader, cash_adjust}
        end
      end
    end
  end

  def trade_by_shares(trader, ticker, shares) do
    share_price =
      ticker
      |> Broker.MarketData.Quote.price()

    trade(trader, ticker, shares, share_price)
  end

  def trade_by_value(trader, ticker, value) do
    share_price =
      ticker
      |> Broker.MarketData.Quote.price()

    shares =
      (value / share_price)
      |> trade_amount_floor()

    trade(trader, ticker, shares, share_price)
  end

  def net_worth(trader) do
    worth(trader)
    |> Map.get(:net_worth)
  end

  def worth(%Trader{holdings: holdings, cash: cash}) do
    prices =
      holdings
      |> Map.keys()
      |> Broker.MarketData.Quote.price()
      |> Enum.into(%{})

    holdings_values =
      holdings
      |> Enum.into(%{}, fn {ticker, shares} ->
        ticker_price = Map.get(prices, ticker)
        value = shares * ticker_price
        {ticker, value}
      end)

    holdings_total =
      Enum.reduce(holdings_values, 0, fn {_, val}, acc ->
        acc + val
      end)

    %{
      holdings_total: holdings_total,
      net_worth: cash + holdings_total,
      prices: prices,
      holdings_values: holdings_values
    }
  end

  defp trade(trader, ticker, share_adjust, share_price) do
    if share_adjust < 0 do
      # selling shares
      with {:ok, trader, cash_adjust} <-
             Trader.update_holdings(trader, ticker, share_adjust, share_price),
           {:ok, trader, _} <-
             Trader.update_cash(trader, cash_adjust, share_adjust, share_price) do
        {:ok, trader}
      end
    else
      # buying shares
      cash_adjust = -(share_adjust * share_price)

      with {:ok, trader, share_adjust} <-
             Trader.update_cash(trader, cash_adjust, share_adjust, share_price),
           {:ok, trader, _} <-
             Trader.update_holdings(trader, ticker, share_adjust, share_price) do
        {:ok, trader}
      end
    end
  end

  defp trade_amount_floor(amount) when amount >= 0, do: floor(amount)
  defp trade_amount_floor(amount) when amount < 0, do: ceil(amount)

  defimpl String.Chars do
    def to_string(%{cash: cash, holdings: holdings, id: id} = trader) do
      %{
        net_worth: net_worth,
        holdings_total: holdings_total,
        prices: prices,
        holdings_values: holdings_values
      } = Trader.worth(trader)

      holdings_rows =
        holdings
        |> Enum.map(fn {ticker, shares} ->
          ticker_price = Map.get(prices, ticker)
          value = Map.get(holdings_values, ticker)

          [
            ticker,
            shares,
            Currency.number_to_currency(ticker_price),
            Currency.number_to_currency(value)
          ]
        end)

      net_worth_value = Currency.number_to_currency(net_worth)
      cash_value = Currency.number_to_currency(cash)
      holdings_value = Currency.number_to_currency(holdings_total)

      summary_rows = [
        divider(),
        ["Holdings Total", nil, nil, holdings_value],
        ["Cash", nil, nil, cash_value],
        divider(),
        ["Net Worth", nil, nil, net_worth_value]
      ]

      make_portfolio_table(holdings_rows ++ summary_rows, id)
    end

    defp divider do
      Enum.map(1..4, fn _ -> "------------" end)
    end

    defp make_portfolio_table(rows, id) do
      rows
      |> Table.new(
        ["Ticker", "Shares", "Price", "Value"],
        Nostrum.Api.get_user!(id).username
      )
      |> Table.put_column_meta(1..3, align: :right)
      |> Table.render!()
    end
  end
end
