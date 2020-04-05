defmodule Broker.Portfolio.Orders do
  alias Broker.Portfolio.Orders

  defstruct sell: %{}, buy: %{}, pending_buys: :queue.new()

  def sell_order(%Orders{sell: sell} = orders, ticker, order) do
    sell = Map.put(sell, ticker, order)
    %Orders{orders | sell: sell}
  end

  def buy_order(%Orders{buy: buy, pending_buys: pending_buys} = orders, ticker, order) do
    {existing_order, buy} =
      Map.get_and_update(buy, ticker, fn val ->
        case val do
          nil ->
            {nil, order}

          val ->
            {val, order}
        end
      end)

    pending_buys =
      case existing_order do
        nil -> :queue.cons(ticker, pending_buys)
        _ -> pending_buys
      end

    %Orders{orders | buy: buy, pending_buys: pending_buys}
  end
end
