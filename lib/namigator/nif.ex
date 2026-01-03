defmodule Namigator.NIF do
  @moduledoc false
  @on_load :load_nif

  def load_nif do
    path = :filename.join(:code.priv_dir(:namigator), ~c"namigator_nif")

    case :erlang.load_nif(path, 0) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def test_add(_a, _b), do: :erlang.nif_error(:not_loaded)
end
