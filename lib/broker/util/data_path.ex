defmodule Util.DataPath do
  def make_data_path do
    path = Application.fetch_env!(:broker, :data_path)
    File.mkdir_p!(path)
  end

  def get_path(filename) do
    path = Application.fetch_env!(:broker, :data_path)
    Path.join(path, stringify(filename))
  end

  defp stringify(filename) when is_binary(filename), do: filename
  defp stringify(filename) when is_atom(filename), do: Atom.to_string(filename)
end
