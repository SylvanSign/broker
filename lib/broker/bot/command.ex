defmodule Broker.Bot.Command do
  alias Nostrum.Api
  alias Number.Currency
  alias TableRex.Table

  def reply("!tutorial", msg) do
    tutorial(msg)
  end

  def reply("!t", msg) do
    tutorial(msg)
  end

  def reply("!help", msg) do
    help(msg)
  end

  def reply("!h", msg) do
    help(msg)
  end

  def reply("!price " <> tickers, msg) do
    price(tickers, msg)
  end

  def reply("!p " <> tickers, msg) do
    price(tickers, msg)
  end

  def reply("! " <> tickers, msg) do
    price(tickers, msg)
  end

  def reply("!buy " <> order, msg) do
    buy(order, msg)
  end

  def reply("!b " <> order, msg) do
    buy(order, msg)
  end

  def reply("!sell " <> order, msg) do
    sell(order, msg)
  end

  def reply("!s " <> order, msg) do
    sell(order, msg)
  end

  def reply("!cancel " <> tickers, msg) do
    cancel_orders(tickers, msg)
  end

  def reply("!c " <> tickers, msg) do
    cancel_orders(tickers, msg)
  end

  def reply("!me", msg) do
    me(msg)
  end

  def reply("!", msg) do
    me(msg)
  end

  def reply("!report", msg) do
    report(msg)
  end

  def reply("!r", msg) do
    report(msg)
  end

  def reply("!leaderboard", msg) do
    report(msg)
  end

  def reply("!l", msg) do
    report(msg)
  end

  def reply("!all", msg) do
    all(msg)
  end

  # # for debugging only, this can be removed eventually
  # def reply("!msg", msg) do
  #   respond("#{inspect(msg, pretty: true)}", msg)
  # end

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

  defp tutorial(%{channel_id: channel_id}) do
    Api.create_message(
      channel_id,
      """
      Hi, I'm Broker! I'm an open-source chat bot that lets you simulate buying and selling securities in the US markets.

      To get started, take a look at your current portfolio
      ```
      !me
      ```
      then take a look at the leaderboard
      ```
      !leaderboard
      ```
      check prices for given tickers
      ```
      !price gme big tsla
      ```
      buy shares
      ```
      !buy 10 f
      ```
      sell shares
      ```
      !sell f $30
      ```
      We'll refer to both "buys" and "sells" collectively as "trades".

      As you can see, for trades, the value can be given in share count (eg. `10`) or dollars (eg. `$20`), and you can provide the ticker or the value first, as long as you provide both.

      I will always execute each trade as much as I can within the limits of your current portfolio. For example, if you have $10 cash and ask to but 2 shares that are currently worth $7 each, I will buy you 1 share @ $7 and leave your $3 cash untouched. Similar logic exists for sells.

      When you make trades during market hours (`9:30am-4:00pm ET, M-F`), I will execute them at based on the current share price. If you make trades outside of those hours, I will queue them up as "trade orders", which will be executed as soon as the markets open up again.

      You can always see a breakdown of your current portfolio, along with any pending trade orders
      ```
      !me
      ```
      For open trade orders, I will queue up the buys in the order that you gave them to me. So if you ask to buy 10 TSLA, then you ask to buy 10 AAPL, I will first try to buy you 10 TSLA shares, then I'll try to buy you 10 AAPL shares. Sells will always be executed before buys, and the sell ordering does not matter.

      To cancel all your orders related to a given ticker or tickers
      ```
      !cancel tsla aapl
      ```
      For a condensed reference of all the commands I understand, along with their shortcuts and more examples
      ```
      !help
      ```
      """
    )
  end

  defp help(%{channel_id: channel_id}) do
    headers = [
      "Command",
      "Shortcut(s)",
      "Example"
    ]

    help_table =
      Table.new(
        [
          [
            "!help",
            "!h",
            nil
          ],
          [
            "!tutorial",
            "!t",
            nil
          ],
          [
            "!me",
            "!",
            nil
          ],
          [
            "!leaderboard",
            "!l",
            nil
          ],
          [
            "!report",
            "!r",
            nil
          ],
          [
            "!price <ticker(s)>",
            "!p, !",
            "! B F"
          ],
          [
            "!buy <amount> <ticker>",
            "!b",
            "!b 10 F"
          ],
          [
            "!sell <amount> <ticker>",
            "!s",
            "!s F $300"
          ],
          [
            "!cancel <ticker(s)>",
            "!c",
            "!c B F"
          ],
          [
            "!all",
            nil,
            nil
          ]
        ],
        headers,
        "Commands I Understand"
      )
      |> Table.render!()

    Api.create_message(
      channel_id,
      """
      ```
      #{help_table}
      ```
      """
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
                        "regularMarketChangePercent" => change_percent,
                        "regularMarketDayHigh" => regular_market_day_high,
                        "regularMarketDayLow" => regular_market_day_low,
                        "regularMarketOpen" => regular_market_open,
                        "regularMarketPreviousClose" => regular_market_previous_close,
                        "fiftyTwoWeekLow" => fifty_two_week_low,
                        "fiftyTwoWeekHigh" => fifty_two_week_high,
                        "regularMarketVolume" => regular_market_volume,
                        "averageDailyVolume3Month" => average_daily_volume_3_month
                      }} ->
        price = Currency.number_to_currency(price)
        price_change_summary = format_price_change(change, change_percent)
        prev_close = Currency.number_to_currency(regular_market_previous_close)
        open = Currency.number_to_currency(regular_market_open)
        day_low = Currency.number_to_currency(regular_market_day_low)
        day_high = Currency.number_to_currency(regular_market_day_high)
        year_low = Currency.number_to_currency(fifty_two_week_low)
        year_high = Currency.number_to_currency(fifty_two_week_high)

        [
          "#{ticker} - #{name}",
          price,
          price_change_summary,
          "prev close #{prev_close}",
          "open       #{open}",
          "daily low  #{day_low}",
          "daily high #{day_high}",
          "52 wk low  #{year_low}",
          "52 wk high #{year_high}",
          "daily vol  #{regular_market_volume}",
          "3M avg vol #{average_daily_volume_3_month}"
        ]
        |> Enum.join("\n")
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

    id = author_id(msg)
    Broker.Portfolio.OrderProcessor.cancel(id, tickers_to_cancel, msg)
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
