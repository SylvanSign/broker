defmodule Util.PersistentCache do
  def get(table, key) when is_atom(table) do
    :ets.lookup(table, key)
    |> handle_lookup()
  end

  def all(table) when is_atom(table) do
    :ets.match(table, :"$1")
    |> Enum.map(&handle_lookup/1)
  end

  def put(table, key, value) when is_atom(table) do
    :ets.insert(table, {key, value})
    save(table)
  end

  # put all entries, where entries looks like [{key1, ...}, {key2, ...}, ...]
  def put_many(table, entries) when is_list(entries) do
    :ets.insert(table, entries)
    save(table)
  end

  defp save(table) do
    file_path = Util.DataPath.get_path("#{table}.state")
    # Note: :ets.tab2file/2 writes the file asynchronously
    :ets.tab2file(table, String.to_atom(file_path))
  end

  def load(table) do
    file_path = Util.DataPath.get_path("#{table}.state")

    if File.exists?(file_path) do
      :ets.file2tab(String.to_atom(file_path))
    else
      Util.DataPath.make_data_path()
      {:ok, new(table)}
    end
  end

  def reset(table) do
    file_path = Util.DataPath.get_path("#{table}.state")

    :ets.delete(table)
    File.rm!(file_path)
    load(table)
  end

  defp new(name) when is_atom(name) do
    opts = [
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ]

    ^name = :ets.new(name, opts)
  end

  defp handle_lookup([{_key, value}]), do: value
  defp handle_lookup([]), do: nil
end
