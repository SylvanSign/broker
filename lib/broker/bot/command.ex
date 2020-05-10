defmodule Broker.Bot.Command do
  alias Nostrum.Api
  alias Nostrum.Struct.User
  alias Number.Currency
  alias TableRex.Table

  def reply("!c " <> tickers, msg) do
    cancel_orders(tickers, msg)
  end

  def reply("!cancel " <> tickers, msg) do
    cancel_orders(tickers, msg)
  end

  def reply("!p " <> tickers, msg) do
    price(tickers, msg)
  end

  def reply("!price " <> tickers, msg) do
    price(tickers, msg)
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
  def reply("!" <> tickers, msg) do
    price(tickers, msg)
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

  defp price(tickers, msg) do
    ticker_info(tickers, msg)
  end

  defp buy(order, msg) do
    trade(:buy, order, msg)
  end

  defp sell(order, msg) do
    trade(:sell, order, msg)
  end

  defp me(msg) do
    id = author_id(msg)

    Broker.Portfolio.Database.fetch_trader(id)
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
    Broker.Portfolio.Database.all_traders()
    |> Enum.map(fn trader ->
      {Broker.Portfolio.Trader.net_worth(trader), trader}
    end)
    |> Enum.sort(fn {nw1, _}, {nw2, _} ->
      nw1 > nw2
    end)
  end

  defp ticker_info(tickers, msg) do
    ticker_infos =
      tickers
      |> String.split(" ")
      |> Enum.map(&transform_ticker/1)
      |> Broker.MarketData.Quote.ticker()
      |> Enum.reject(fn {_, info} -> Enum.empty?(info) end)
      |> Enum.map(fn {ticker,
                      %{
                        "regularMarketPrice" => price,
                        "longName" => name,
                        "regularMarketChange" => change,
                        "regularMarketChangePercent" => change_percent
                      }} ->
        price = Currency.number_to_currency(price)
        price_change_summary = format_price_change(change, change_percent)

        "#{ticker} - #{name}\n#{price}\n#{price_change_summary}"
      end)
      |> Enum.join("\n\n")

    unless ticker_infos == "" do
      respond(ticker_infos, msg)
    end
  end

  defp cancel_orders(tickers, msg) do
    tickers_to_cancel =
      tickers
      |> String.split(" ")
      |> Enum.map(&transform_ticker/1)

    unless tickers_to_cancel == "" do
      id = author_id(msg)

      Broker.Portfolio.OrderProcessor.cancel(id, tickers_to_cancel, msg)
    end
  end

  defp format_price_change(change, change_percent) do
    change_postitive? = change > 0
    maybe_plus_sign = if change_postitive?, do: "+", else: ""
    arrow = if change_postitive?, do: "↑", else: "↓"

    change_money = Currency.number_to_currency(change)

    formatted_change_percent =
      change_percent
      |> abs()
      |> Float.round(2)

    "#{maybe_plus_sign}#{change_money} (#{formatted_change_percent}%) #{arrow}"
  end

  def respond(message, %{channel_id: channel_id}) do
    Api.create_message(
      channel_id,
      "```diff\n#{message}\n```"
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

    Broker.Portfolio.OrderProcessor.trade(amount_type, id, ticker, amount, msg)
  end
end
