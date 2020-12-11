defmodule Broker.Portfolio.OrderProcessor do
  use GenStateMachine
  alias Broker.Portfolio.Database
  alias Broker.Portfolio.Trader
  alias Broker.Portfolio.Orders

  @name __MODULE__

  @monday 1
  @friday 5
  @weekdays @monday..@friday
  @trade_open Time.new(9, 30, 0) |> elem(1)
  @trade_close Time.new(16, 0, 0) |> elem(1)

  def start_link([]) do
    GenStateMachine.start_link(@name, nil, name: @name)
  end

  def init(nil) do
    state =
      if trading_open?() do
        open()
        :open
      else
        :closed
      end

    {:ok, state, nil}
  end

  def state do
    GenStateMachine.call(@name, :state)
  end

  def open do
    GenStateMachine.cast(@name, :open)
  end

  def close do
    GenStateMachine.cast(@name, :close)
  end

  def trade(amount_type, id, ticker, amount, msg) do
    GenStateMachine.cast(@name, {:trade, amount_type, id, ticker, amount, msg})
  end

  def cancel(id, tickers_to_cancel, msg) do
    GenStateMachine.cast(@name, {:cancel, id, tickers_to_cancel, msg})
  end

  def handle_event({:call, from}, :state, state, data) do
    {:next_state, state, data, [{:reply, from, state}]}
  end

  def handle_event(:cast, {:cancel, id, tickers_to_cancel, msg}, :closed, data) do
    trader =
      Database.fetch_trader(id)
      |> Trader.update_orders(fn orders ->
        Orders.cancel(orders, tickers_to_cancel)
      end)
      |> Database.store_trader()

    Broker.Bot.Command.respond(trader, msg)
    {:next_state, :closed, data}
  end

  def handle_event(:cast, {:cancel, _, _, msg}, :open, data) do
    Broker.Bot.Command.respond("Markets are open, no orders to cancel", msg)
    {:next_state, :open, data}
  end

  def handle_event(:cast, {:trade, amount_type, id, ticker, amount, msg}, :closed, data) do
    IO.puts("asked to trade when closed, so gonna queue it up...")

    order_fn =
      if amount > 0 do
        &Orders.buy_order/3
      else
        &Orders.sell_order/3
      end

    trader =
      Database.fetch_trader(id)
      |> Trader.update_orders(fn orders ->
        order_fn.(orders, ticker, {amount_type, amount})
      end)
      |> Database.store_trader()

    Broker.Bot.Command.respond(trader, msg)

    {:next_state, :closed, data}
  end

  def handle_event(:cast, {:trade, amount_type, id, ticker, amount, msg}, :open, data) do
    IO.puts("Open for business, so gonna make trade now...")

    trade_function =
      case amount_type do
        :value ->
          &Database.trade_by_value/3

        :shares ->
          &Database.trade_by_shares/3
      end

    IO.puts("Handling trade order - id: #{id} - ticker: #{ticker} - amount: #{amount}")

    case trade_function.(id, ticker, amount) do
      {:error, error} ->
        Broker.Bot.Command.respond("I can't do that because #{error}.", msg)

      {:ok, trader} ->
        Broker.Bot.Command.respond(trader, msg)
    end

    {:next_state, :open, data}
  end

  def handle_event(:cast, :open, _, data) do
    IO.puts("opening...")
    IO.puts("executing orders...")
    execute_orders()
    IO.puts("all orders executed!")
    {:next_state, :open, data}
  end

  def handle_event(:cast, :close, _, data) do
    IO.puts("closing...")
    {:next_state, :closed, data}
  end

  def trading_open?(now_dt \\ DateTime.now!("America/New_York")) do
    proper_day? = Date.day_of_week(now_dt) in @weekdays
    after_open? = Time.compare(now_dt, @trade_open) != :lt
    before_close? = Time.compare(@trade_close, now_dt) == :gt
    proper_day? and after_open? and before_close?
  end

  def execute_orders do
    traders = Database.all_traders()

    price_map =
      traders
      |> collect_tickers_to_price()
      |> Broker.MarketData.Quote.price()

    traders
    |> execute_sells(price_map)
    |> execute_buys(price_map)
    |> clear_orders()
  end

  def execute_sells(traders, price_map) do
    Enum.map(traders, fn %{orders: %{sell: sells}} = trader ->
      Enum.reduce(sells, trader, fn {ticker, {amount_type, amount}}, trader ->
        share_price = price_map[ticker]

        trade_function =
          case amount_type do
            :value ->
              &Trader.trade_by_value/4

            :shares ->
              &Trader.trade_by_shares/4
          end

        case trade_function.(trader, ticker, amount, share_price) do
          {:ok, updated_trader} -> updated_trader
          _ -> trader
        end
      end)
    end)
  end

  def execute_buys(traders, price_map) do
    Enum.map(traders, fn %{orders: %{buy: buys, pending_buys: pending_buys}} = trader ->
      # we have decided to execute buys in FIFO order, for now
      Enum.reduce(:queue.to_list(pending_buys), trader, fn ticker, trader ->
        {amount_type, amount} = buys[ticker]
        share_price = price_map[ticker]

        trade_function =
          case amount_type do
            :value ->
              &Trader.trade_by_value/4

            :shares ->
              &Trader.trade_by_shares/4
          end

        case trade_function.(trader, ticker, amount, share_price) do
          {:ok, updated_trader} -> updated_trader
          _ -> trader
        end
      end)
    end)
  end

  def clear_orders(traders) do
    Enum.map(traders, &Database.store_trader(%{&1 | orders: %Orders{}}))
  end

  def collect_tickers_to_price(traders) do
    traders
    |> Enum.reduce(MapSet.new(), fn %{orders: orders}, ticker_set ->
      sell_tickers = orders.sell |> Map.keys() |> MapSet.new()
      buy_tickers = orders.buy |> Map.keys() |> MapSet.new()

      ticker_set
      |> MapSet.union(sell_tickers)
      |> MapSet.union(buy_tickers)
    end)
    |> MapSet.to_list()
  end
end
