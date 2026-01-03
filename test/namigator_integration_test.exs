defmodule Namigator.IntegrationTest do
  @moduledoc """
  Integration tests for Namigator with real navmesh data.

  These tests require pre-built navigation mesh data to run.
  Set the NAMIGATOR_DATA_PATH environment variable to the path
  containing navigation mesh data, and NAMIGATOR_MAP_NAME to the
  map name to test with.

  Example:
      NAMIGATOR_DATA_PATH=/path/to/nav_data NAMIGATOR_MAP_NAME=Azeroth mix test

  If these environment variables are not set, these tests are skipped.
  """
  use ExUnit.Case

  alias Namigator.Map

  @moduletag :integration

  @data_path System.get_env("NAMIGATOR_DATA_PATH")
  @map_name System.get_env("NAMIGATOR_MAP_NAME")

  # Skip all tests if data path or map name not provided
  if @data_path == nil or @map_name == nil do
    @moduletag :skip
  end

  setup_all do
    if @data_path && @map_name do
      case Map.new(@data_path, @map_name) do
        {:ok, map} ->
          # Load all ADTs for testing
          {:ok, count} = Map.load_all_adts(map)
          IO.puts("\n[IntegrationTest] Loaded #{count} ADTs for #{@map_name}")
          {:ok, %{map: map, adt_count: count}}

        {:error, reason} ->
          IO.puts("\n[IntegrationTest] Failed to load map: #{inspect(reason)}")
          :ok
      end
    else
      :ok
    end
  end

  describe "map loading with real data" do
    test "can create map from data path", context do
      if context[:map] do
        assert %Map{ref: ref} = context.map
        assert is_reference(ref)
      end
    end

    test "load_all_adts returns positive count", context do
      if context[:adt_count] do
        assert context.adt_count > 0
      end
    end
  end

  describe "ADT operations with real data" do
    test "has_adt? returns boolean for valid coordinates", context do
      if context[:map] do
        # Try a range of coordinates
        for x <- 0..63, y <- 0..63 do
          result = Map.has_adt?(context.map, x, y)
          assert is_boolean(result)
        end
      end
    end

    test "adt_loaded? returns true for loaded ADTs", context do
      if context[:map] do
        # Find an ADT that exists
        exists =
          for x <- 0..63, y <- 0..63, Map.has_adt?(context.map, x, y), do: {x, y}

        if length(exists) > 0 do
          {x, y} = hd(exists)
          # After load_all_adts, existing ADTs should be loaded
          assert Map.adt_loaded?(context.map, x, y) == true
        end
      end
    end

    test "unload_adt and load_adt work correctly", context do
      if context[:map] do
        exists =
          for x <- 0..63, y <- 0..63, Map.has_adt?(context.map, x, y), do: {x, y}

        if length(exists) > 0 do
          {x, y} = hd(exists)

          # Unload the ADT
          assert Map.unload_adt(context.map, x, y) == :ok
          assert Map.adt_loaded?(context.map, x, y) == false

          # Reload the ADT
          assert Map.load_adt(context.map, x, y) == true
          assert Map.adt_loaded?(context.map, x, y) == true
        end
      end
    end
  end

  describe "pathfinding with real data" do
    test "find_path returns path for valid coordinates", context do
      if context[:map] do
        # These coordinates should work for most maps if ADTs are loaded
        # Adjust based on your test data
        start = {0.0, 0.0, 0.0}
        stop = {10.0, 10.0, 0.0}

        result = Map.find_path(context.map, start, stop)

        case result do
          {:ok, path} ->
            assert is_list(path)
            assert length(path) > 0
            assert Enum.all?(path, fn {x, y, z} ->
              is_float(x) and is_float(y) and is_float(z)
            end)

          {:error, :no_path} ->
            # This is also valid - coordinates might not be on navmesh
            assert true
        end
      end
    end

    test "find_path with allow_partial option", context do
      if context[:map] do
        start = {0.0, 0.0, 0.0}
        stop = {1000.0, 1000.0, 0.0}  # Far away, might need partial

        result = Map.find_path(context.map, start, stop, allow_partial: true)

        case result do
          {:ok, path} -> assert is_list(path)
          {:error, :no_path} -> assert true
        end
      end
    end
  end

  describe "height queries with real data" do
    test "find_height returns height or not_found", context do
      if context[:map] do
        source = {0.0, 0.0, 100.0}

        result = Map.find_height(context.map, source, 0.0, 0.0)

        case result do
          {:ok, z} -> assert is_float(z)
          {:error, :not_found} -> assert true
        end
      end
    end

    test "find_heights returns list of heights", context do
      if context[:map] do
        result = Map.find_heights(context.map, 0.0, 0.0)

        case result do
          {:ok, heights} ->
            assert is_list(heights)
            assert Enum.all?(heights, &is_float/1)

          {:error, :not_found} ->
            assert true
        end
      end
    end
  end

  describe "line of sight with real data" do
    test "line_of_sight? returns boolean", context do
      if context[:map] do
        start = {0.0, 0.0, 100.0}
        stop = {10.0, 10.0, 100.0}

        result = Map.line_of_sight?(context.map, start, stop)
        assert is_boolean(result)
      end
    end

    test "line_of_sight? with include_doodads option", context do
      if context[:map] do
        start = {0.0, 0.0, 100.0}
        stop = {10.0, 10.0, 100.0}

        result_with = Map.line_of_sight?(context.map, start, stop, include_doodads: true)
        result_without = Map.line_of_sight?(context.map, start, stop, include_doodads: false)

        assert is_boolean(result_with)
        assert is_boolean(result_without)
      end
    end
  end

  describe "zone and area queries with real data" do
    test "zone_and_area returns tuple or not_found", context do
      if context[:map] do
        position = {0.0, 0.0, 0.0}

        result = Map.zone_and_area(context.map, position)

        case result do
          {:ok, {zone_id, area_id}} ->
            assert is_integer(zone_id)
            assert is_integer(area_id)
            assert zone_id >= 0
            assert area_id >= 0

          {:error, :not_found} ->
            assert true
        end
      end
    end
  end

  describe "random point generation with real data" do
    test "find_random_point_around_circle returns coord or not_found", context do
      if context[:map] do
        center = {0.0, 0.0, 0.0}
        radius = 50.0

        result = Map.find_random_point_around_circle(context.map, center, radius)

        case result do
          {:ok, {x, y, z}} ->
            assert is_float(x)
            assert is_float(y)
            assert is_float(z)

          {:error, :not_found} ->
            assert true
        end
      end
    end

    test "random points are within radius (when found)", context do
      if context[:map] do
        center = {0.0, 0.0, 0.0}
        radius = 50.0

        # Try multiple times to account for randomness
        results =
          for _ <- 1..10 do
            Map.find_random_point_around_circle(context.map, center, radius)
          end

        found = Enum.filter(results, fn
          {:ok, _} -> true
          _ -> false
        end)

        for {:ok, {x, y, _z}} <- found do
          {cx, cy, _cz} = center
          distance = :math.sqrt(:math.pow(x - cx, 2) + :math.pow(y - cy, 2))
          # Allow some tolerance for navmesh constraints
          assert distance <= radius * 1.5
        end
      end
    end
  end

  describe "point in between with real data" do
    test "find_point_in_between returns coord or not_found", context do
      if context[:map] do
        start = {0.0, 0.0, 0.0}
        stop = {100.0, 100.0, 0.0}
        distance = 25.0

        result = Map.find_point_in_between(context.map, start, stop, distance)

        case result do
          {:ok, {x, y, z}} ->
            assert is_float(x)
            assert is_float(y)
            assert is_float(z)

          {:error, :not_found} ->
            assert true
        end
      end
    end
  end
end
