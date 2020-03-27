defmodule Broker.Bot.Command do
  alias Nostrum.Api
  alias Nostrum.Struct.User
  alias Number.Currency
  alias TableRex.Table

  def reply("!p " <> ticker, msg) do
    price(ticker, msg)
  end

  def reply("!price " <> ticker, msg) do
    price(ticker, msg)
  end

  def reply("!b " <> order, msg) do
    buy(order, msg)
  end

  def reply("!buy " <> order, msg) do
    buy(order, msg)
  end

  def reply("!s " <> order, msg) do
    sell(order, msg)
  end

  def reply("!sell " <> order, msg) do
    sell(order, msg)
  end

  def reply("!", msg) do
    me(msg)
  end

  def reply("!me", msg) do
    me(msg)
  end

  def reply("!r", msg) do
    report(msg)
  end

  def reply("!report", msg) do
    report(msg)
  end

  def reply("!all", msg) do
    all(msg)
  end

  def reply("!h", msg) do
    missing_feature(msg)
  end

  def reply("!help", msg) do
    missing_feature(msg)
  end

  # for debugging only, this can be removed eventually
  def reply("!msg", msg) do
    respond("#{inspect(msg, pretty: true)}", msg)
  end

  # this is a special price shortcut, but I want it to be the last priority in
  # case we get ambiguous conflicts like `!all`, which could mean either
  # - "price ALL" (Allstate)
  # or
  # - "show me all portfolios"
  def reply("!" <> ticker, msg) do
    price(ticker, msg)
  end

  def reply(_contents, _msg) do
    :ignore
  end

  def report_message(title \\ "Leaderboard") do
    all_traders_worth_data()
    |> Enum.map(fn {nw, %{id: id, holdings: holdings}} ->
      hs =
        holdings
        |> Map.keys()
        |> Enum.sort()
        |> Enum.join(" | ")

      [Nostrum.Api.get_user!(id).username, Currency.number_to_currency(nw), hs]
    end)
    |> Enum.with_index(1)
    |> Enum.map(fn {trader_columns, rank} ->
      [rank | trader_columns]
    end)
    |> Table.new(
      ["Rank", "Username", "Net Worth", "Holdings"],
      title
    )
    |> Table.put_column_meta(2, align: :right)
    |> Table.render!()
  end

  defp price(ticker, msg) do
    ticker_info(ticker, msg)
  end

  defp buy(order, msg) do
    trade(:buy, order, msg)
  end

  defp sell(order, msg) do
    trade(:sell, order, msg)
  end

  defp me(msg) do
    id = author_id(msg)

    Broker.Portfolio.Data.fetch_trader(id)
    |> respond(msg)
  end

  defp report(msg) do
    report_message()
    |> respond(msg)
  end

  defp all(msg) do
    all_traders_worth_data()
    |> Enum.each(fn {_, trader} ->
      Process.sleep(1000)
      respond(trader, msg)
    end)
  end

  defp missing_feature(%{channel_id: channel_id, author: author}) do
    # TODO, create actual help display

    Api.create_message(
      channel_id,
      "Somebody needs to teach me how to reply to this!\nThat can be done by contributing to https://github.com/SylvanSign/broker\n\nAre you the chosen one, #{
        User.mention(author)
      }?"
    )
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
    |> respond(msg)
  end

  defp respond(message, %{channel_id: channel_id}) do
    Api.create_message(
      channel_id,
      "```\n#{message}\n```"
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

  defp trade(trade_type, order, msg) do
    [amount_string, ticker] =
      order
      |> String.split()
      |> Enum.sort()

    {amount_type, amount} =
      if String.starts_with?(amount_string, "$") do
        ["", amount_string] = String.split(amount_string, "$")
        {amount, ""} = Float.parse(amount_string)
        {:value, amount}
      else
        {amount, ""} = Integer.parse(amount_string)

        {:shares, amount}
      end

    amount =
      case trade_type do
        :buy -> amount
        :sell -> -amount
      end

    ticker = transform_ticker(ticker)
    id = author_id(msg)

    trade_function =
      case amount_type do
        :value ->
          &Broker.Portfolio.Data.trade_by_value/3

        :shares ->
          &Broker.Portfolio.Data.trade_by_shares/3
      end

    case trade_function.(id, ticker, amount) do
      {:error, error} ->
        respond("I can't do that because #{error}.", msg)

      {:ok, trader} ->
        respond(trader, msg)
    end
  end
end
