defmodule Namigator.NIF do
  @moduledoc false

  @on_load :load_nif

  @type map_ref :: reference()
  @type coord :: {float(), float(), float()}

  # ADT grid bounds (0-63 for 64x64 grid)
  @adt_min 0
  @adt_max 63

  def load_nif do
    path = :filename.join(:code.priv_dir(:namigator), ~c"namigator_nif")

    case :erlang.load_nif(path, 0) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Validates ADT coordinates are within bounds (0-63)
  defp validate_adt_coords!(x, y) do
    unless is_integer(x) and is_integer(y) and
             x >= @adt_min and x <= @adt_max and
             y >= @adt_min and y <= @adt_max do
      raise ArgumentError, "ADT coordinates must be between 0 and 63"
    end
  end

  # Test function
  @spec test_add(integer(), integer()) :: integer()
  def test_add(_a, _b), do: :erlang.nif_error(:not_loaded)

  # Map resource functions
  @spec map_new(String.t(), String.t()) :: map_ref()
  def map_new(_data_path, _map_name), do: :erlang.nif_error(:not_loaded)

  # ADT loading
  @spec map_load_all_adts(map_ref()) :: integer()
  def map_load_all_adts(_map), do: :erlang.nif_error(:not_loaded)

  @spec map_load_adt(map_ref(), integer(), integer()) :: boolean()
  def map_load_adt(map, x, y) do
    validate_adt_coords!(x, y)
    map_load_adt_nif(map, x, y)
  end

  defp map_load_adt_nif(_map, _x, _y), do: :erlang.nif_error(:not_loaded)

  @spec map_unload_adt(map_ref(), integer(), integer()) :: :ok
  def map_unload_adt(map, x, y) do
    validate_adt_coords!(x, y)
    map_unload_adt_nif(map, x, y)
  end

  defp map_unload_adt_nif(_map, _x, _y), do: :erlang.nif_error(:not_loaded)

  @spec map_has_adt(map_ref(), integer(), integer()) :: boolean()
  def map_has_adt(map, x, y) do
    validate_adt_coords!(x, y)
    map_has_adt_nif(map, x, y)
  end

  defp map_has_adt_nif(_map, _x, _y), do: :erlang.nif_error(:not_loaded)

  @spec map_is_adt_loaded(map_ref(), integer(), integer()) :: boolean()
  def map_is_adt_loaded(map, x, y) do
    validate_adt_coords!(x, y)
    map_is_adt_loaded_nif(map, x, y)
  end

  defp map_is_adt_loaded_nif(_map, _x, _y), do: :erlang.nif_error(:not_loaded)

  # Pathfinding functions
  @spec map_find_path(map_ref(), coord(), coord(), boolean()) ::
          {:ok, [coord()]} | {:error, :no_path}
  def map_find_path(_map, _start, _stop, _allow_partial), do: :erlang.nif_error(:not_loaded)

  @spec map_find_height(map_ref(), coord(), float(), float()) ::
          {:ok, float()} | {:error, :not_found}
  def map_find_height(_map, _source, _x, _y), do: :erlang.nif_error(:not_loaded)

  @spec map_find_heights(map_ref(), float(), float()) ::
          {:ok, [float()]} | {:error, :not_found}
  def map_find_heights(_map, _x, _y), do: :erlang.nif_error(:not_loaded)

  # Spatial query functions
  @spec map_line_of_sight(map_ref(), coord(), coord(), boolean()) :: boolean()
  def map_line_of_sight(_map, _start, _stop, _include_doodads), do: :erlang.nif_error(:not_loaded)

  @spec map_zone_and_area(map_ref(), coord()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, :not_found}
  def map_zone_and_area(_map, _position), do: :erlang.nif_error(:not_loaded)

  @spec map_find_random_point_around_circle(map_ref(), coord(), float()) ::
          {:ok, coord()} | {:error, :not_found}
  def map_find_random_point_around_circle(_map, _center, _radius),
    do: :erlang.nif_error(:not_loaded)

  @spec map_find_point_in_between(map_ref(), coord(), coord(), float()) ::
          {:ok, coord()} | {:error, :not_found}
  def map_find_point_in_between(_map, _start, _stop, _distance), do: :erlang.nif_error(:not_loaded)
end
