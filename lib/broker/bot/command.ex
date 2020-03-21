defmodule Broker.Bot.Command do
  alias Nostrum.Api
  alias Nostrum.Struct.User
  alias Number.Currency
  alias TableRex.Table

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

    Broker.Portfolio.Data.fetch_trader(id)
    |> respond_to_user(msg)
  end

  def reply("!report", msg) do
    all_traders_worth_data()
    |> Enum.map(fn {nw, %{id: id}} ->
      [Nostrum.Api.get_user!(id).username, Currency.number_to_currency(nw)]
    end)
    |> Enum.with_index(1)
    |> Enum.map(fn {[username, nw], rank} ->
      [rank, username, nw]
    end)
    |> Table.new(
      ["Rank", "Username", "Net Worth"],
      "Leaderboard"
    )
    |> Table.put_column_meta(2, align: :right)
    |> Table.render!()
    |> respond_to_user(msg)
  end

  def reply("!all", msg) do
    all_traders_worth_data()
    |> Enum.each(fn {_, trader} ->
      Process.sleep(1000)
      respond(trader, msg)
    end)
  end

  def reply("!msg", msg) do
    respond_to_user("#{inspect(msg, pretty: true)}", msg)
  end

  def reply("!" <> ticker, msg) do
    ticker_info(ticker, msg)
  end

  def reply(_contents, _msg) do
    :ignore
  end

  defp all_traders_worth_data() do
    Broker.Portfolio.Data.all_traders()
    |> Enum.map(fn trader ->
      {Broker.Portfolio.Trader.net_worth(trader), trader}
    end)
    |> Enum.sort(fn {nw1, _}, {nw2, _} ->
      nw1 > nw2
    end)
  end

  defp ticker_info(ticker, msg) do
    ticker = transform_ticker(ticker)

    %{"regularMarketPrice" => price, "longName" => longName} =
      ticker
      |> Broker.MarketData.Quote.ticker()

    "#{longName} | #{ticker} | #{Currency.number_to_currency(price)}"
    |> respond_to_user(msg)
  end

  defp respond(message, %{channel_id: channel_id}) do
    Api.create_message(
      channel_id,
      "```\n#{message}\n```#{if Mix.env() == :dev, do: " from DEV", else: ""}"
    )
  end

  defp respond_to_user(message, %{channel_id: channel_id, author: author}) do
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
        respond_to_user("I can't do that because #{error}.", msg)

      {:ok, trader} ->
        respond_to_user(trader, msg)
    end
  end
end
