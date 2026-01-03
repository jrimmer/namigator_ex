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

  # Test function
  def test_add(_a, _b), do: :erlang.nif_error(:not_loaded)

  # Map resource functions
  def map_new(_data_path, _map_name), do: :erlang.nif_error(:not_loaded)
  def map_load_all_adts(_map), do: :erlang.nif_error(:not_loaded)
  def map_load_adt(_map, _x, _y), do: :erlang.nif_error(:not_loaded)
  def map_unload_adt(_map, _x, _y), do: :erlang.nif_error(:not_loaded)
  def map_has_adt(_map, _x, _y), do: :erlang.nif_error(:not_loaded)
  def map_is_adt_loaded(_map, _x, _y), do: :erlang.nif_error(:not_loaded)

  # Pathfinding functions
  def map_find_path(_map, _start, _stop, _allow_partial), do: :erlang.nif_error(:not_loaded)
  def map_find_height(_map, _source, _x, _y), do: :erlang.nif_error(:not_loaded)
  def map_find_heights(_map, _x, _y), do: :erlang.nif_error(:not_loaded)
  def map_line_of_sight(_map, _start, _stop, _include_doodads), do: :erlang.nif_error(:not_loaded)
  def map_zone_and_area(_map, _position), do: :erlang.nif_error(:not_loaded)
  def map_find_random_point_around_circle(_map, _center, _radius), do: :erlang.nif_error(:not_loaded)
  def map_find_point_in_between(_map, _start, _stop, _distance), do: :erlang.nif_error(:not_loaded)
end
