defmodule Namigator do
  @moduledoc """
  Namigator is an Elixir binding for the namigator pathfinding library.

  Namigator provides navigation mesh (navmesh) pathfinding capabilities for
  World of Warcraft server emulators. It wraps the C++ namigator library which
  uses Recast/Detour for navigation mesh operations.

  ## Usage

  First, create a map from pre-built navigation mesh data:

      {:ok, map} = Namigator.Map.new("/path/to/nav_data", "Azeroth")

  Load the area data tiles (ADTs) you need:

      {:ok, _count} = Namigator.Map.load_all_adts(map)
      # or load specific tiles:
      Namigator.Map.load_adt(map, 32, 48)

  Find paths between points:

      start = {-8949.95, -132.493, 83.5312}
      stop = {-8898.63, -179.715, 79.8297}

      case Namigator.Map.find_path(map, start, stop) do
        {:ok, path} ->
          # path is a list of {x, y, z} tuples
          IO.inspect(path)
        {:error, :no_path} ->
          IO.puts("No path found")
      end

  Check line of sight:

      if Namigator.Map.line_of_sight?(map, start, stop) do
        IO.puts("Clear line of sight!")
      end

  ## Building Navigation Data

  The navigation mesh data must be pre-built using the namigator map builder tool.
  See the namigator project for instructions on building navigation data from
  game client files.
  """
end
