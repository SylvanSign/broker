defmodule Broker.MarketData.Quote do
  @default_fields ~w(
    longName
    regularMarketPrice
    regularMarketChange
    regularMarketChangePercent
  )

  def price([]) do
    []
  end

  def price(tickers) when is_list(tickers) do
    data(tickers, ["regularMarketPrice"])
    |> Enum.into(%{}, fn {ticker, %{"regularMarketPrice" => p}} ->
      {ticker, Float.round(p, 2)}
    end)
  end

  def price(ticker) do
    data(ticker, ["regularMarketPrice"])
    |> Map.get("regularMarketPrice")
    |> Float.round(2)
  end

  def ticker(tickers) when is_list(tickers) do
    data(tickers, @default_fields)
  end

  def ticker(ticker) do
    data(ticker, @default_fields)
  end

  def data(tickers, fields_to_take \\ :all)

  def data(tickers, fields_to_take) when is_list(tickers) do
    tickers = Enum.join(tickers, ",")

    quote_request(tickers)
    |> Enum.into(%{}, fn result ->
      case fields_to_take do
        :all ->
          {result["symbol"], result}

        fields ->
          {result["symbol"], Map.take(result, fields)}
      end
    end)
  end

  def data(ticker, fields_to_take) do
    result =
      quote_request(ticker)
      |> hd()

    case fields_to_take do
      :all ->
        result

      fields ->
        Map.take(result, fields)
    end
  end

  defp quote_request(symbols) do
    HTTPoison.get!("https://query1.finance.yahoo.com/v7/finance/quote?symbols=#{symbols}")
    |> Map.get(:body)
    |> Poison.decode!()
    |> get_in(["quoteResponse", "result"])
  end
end
