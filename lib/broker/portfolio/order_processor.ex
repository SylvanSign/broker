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
    state = if trading_open?(), do: :open, else: :closed

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

  def handle_event({:call, from}, :state, state, data) do
    {:next_state, state, data, [{:reply, from, state}]}
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
        order_fn.(orders, ticker, {amount_type, id, ticker, amount, msg})
      end)
      |> Database.store_trader()

    IO.puts(trader)

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

    case trade_function.(id, ticker, amount) do
      {:error, error} ->
        Broker.Bot.Command.respond("I can't do that because #{error}.", msg)

      {:ok, trader} ->
        Broker.Bot.Command.respond(trader, msg)
    end

    {:next_state, :open, data}
  end

  def handle_event(:cast, :open, _, data) do
    {:next_state, :open, data}
  end

  def handle_event(:cast, :close, _, data) do
    {:next_state, :closed, data}
  end

  def trading_open?(now_dt \\ DateTime.now!("America/New_York")) do
    proper_day? = Date.day_of_week(now_dt) in @weekdays
    after_open? = Time.compare(now_dt, @trade_open) != :lt
    before_close? = Time.compare(@trade_close, now_dt) == :gt
    proper_day? and after_open? and before_close?
  end
end
