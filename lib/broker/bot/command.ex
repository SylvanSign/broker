defmodule Broker.Bot.Command do
  alias Nostrum.Api
  alias Nostrum.Struct.User
  alias Number.Currency

  def reply("!price " <> ticker, msg) do
    ticker_info(ticker, msg)
  end

  def reply("!buy " <> order, msg) do
    trade(:buy, order, msg)
  end

  def reply("!sell " <> order, msg) do
    trade(:sell, order, msg)
  end

  def reply("!me", msg) do
    id = author_id(msg)
    trader = Broker.Portfolio.Data.fetch_trader(id)
    reply_to_user(msg, trader)
  end

  def reply("!msg", msg) do
    reply_to_user(msg, "#{inspect(msg, pretty: true)}")
  end

  def reply("!" <> ticker, msg) do
    ticker_info(ticker, msg)
  end

  def reply(_contents, _msg) do
    :ignore
  end

  defp ticker_info(ticker, msg) do
    ticker = transform_ticker(ticker)

    %{"regularMarketPrice" => price, "longName" => longName} =
      ticker
      |> Broker.MarketData.Quote.ticker()

    reply_to_user(
      msg,
      "#{longName} | #{ticker} | #{Currency.number_to_currency(price)}"
    )
  end

  defp reply_to_user(%{channel_id: channel_id, author: author}, message) do
    Api.create_message(
      channel_id,
      "```\n#{message}\n```#{User.mention(author)}#{
        if Mix.env() == :dev, do: " from DEV", else: ""
      }"
    )
  end

  defp author_id(%{author: %{id: id}}) do
    id
  end

  defp transform_ticker(ticker) do
    ticker
    |> String.trim()
    |> String.upcase()
  end

  defp trade(type, order, msg) do
    [shares_str, ticker] =
      order
      |> String.split()
      |> Enum.sort()

    {shares, ""} = Integer.parse(shares_str)

    shares =
      case type do
        :buy -> shares
        :sell -> -shares
      end

    ticker = transform_ticker(ticker)

    id = author_id(msg)

    case Broker.Portfolio.Data.trade(id, ticker, shares) do
      {:error, error} ->
        reply_to_user(msg, "I can't do that because #{error}.")

      {:ok, trader} ->
        reply_to_user(msg, trader)
    end
  end
end
