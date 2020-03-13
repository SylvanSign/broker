defmodule Broker.Portfolio do
  alias Number.Currency

  defmodule Game do
    defstruct traders: %{}
  end

  defmodule Trader do
    defstruct [:id, cash: 1_000, holdings: %{}]

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

    defimpl String.Chars do
      def to_string(%{cash: cash, holdings: holdings}) do
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

        holdings_messages =
          holdings
          |> Enum.map(fn {ticker, shares} ->
            ticker_price = Map.get(prices, ticker)
            value = Map.get(holdings_values, ticker)

            "  #{ticker} => #{shares} x #{Currency.number_to_currency(ticker_price)} = #{
              Currency.number_to_currency(value)
            }"
          end)
          |> Enum.join("\n")

        net_worth = Currency.number_to_currency(cash + holdings_total)
        cash = Currency.number_to_currency(cash)
        portfolio = Currency.number_to_currency(holdings_total)

        "net worth: #{net_worth}\n\ncash: #{cash}\nportfolio: #{portfolio}\nholdings:\n#{
          holdings_messages
        }"
      end
    end
  end
end
