defmodule Broker.Portfolio do
  alias Number.Currency
  alias TableRex.Table

  defmodule Game do
    defstruct traders: %{}
  end

  defmodule Trader do
    defstruct [:id, cash: 100_000, holdings: %{}]

    def update_cash(%Trader{cash: cash} = trader, cash_change) do
      balance = cash + cash_change

      if balance < 0 do
        {:error, "you don't have enough cash"}
      else
        {:ok, %Trader{trader | cash: balance |> Float.round(2)}}
      end
    end

    def update_holdings(%Trader{holdings: holdings} = trader, ticker, share_change) do
      shares = Map.get(holdings, ticker, 0)
      balance = shares + share_change

      if balance < 0 do
        {:error, "you don't have enough #{ticker} shares"}
      else
        if balance == 0 do
          {:ok, %Trader{trader | holdings: Map.delete(holdings, ticker)}}
        else
          {:ok, %Trader{trader | holdings: Map.put(holdings, ticker, balance)}}
        end
      end
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
end
