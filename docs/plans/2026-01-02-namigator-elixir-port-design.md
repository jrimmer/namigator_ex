# Namigator Elixir Port Design

## Overview

Port the namigator C++ pathfinding library to Elixir as a standalone hex package using Fine for NIF bindings.

**Goals:**
- Direct C++ integration (no Rust middleman)
- Standalone hex package usable by any Elixir WoW emulator
- Simple `mix deps.get && mix compile` experience

**Non-goals:**
- MapBuilder/parser (mesh generation is separate tooling)
- OTP patterns (GenServer, supervision) - left to consuming apps

## Architecture

### Package Structure

```
namigator/
├── mix.exs                           # elixir_make, hex config
├── Makefile                          # Builds NIF + vendored C++
├── c_src/
│   ├── namigator_nif.cpp            # Fine NIF (~200 lines)
│   ├── fine/                        # Vendored Fine headers
│   ├── namigator/                   # Vendored (pathfind + utility only)
│   │   ├── pathfind/
│   │   ├── utility/
│   │   └── Common.hpp
│   └── recastnavigation/            # Vendored (Detour only)
│       └── Detour/
├── lib/
│   ├── namigator.ex                 # Delegates to Namigator.Map
│   └── namigator/
│       ├── nif.ex                   # Low-level bindings
│       └── map.ex                   # Thin struct wrapper
├── priv/
│   └── .gitkeep                     # NIF .so goes here
└── test/
    └── namigator_test.exs
```

### Layer Design

**Layer 1: NIF (Namigator.NIF)**
- Direct Fine bindings to namigator C API
- `map_new/2` returns Fine `ResourcePtr<pathfind::Map>`
- Individual float parameters for coordinates (matches thistle_tea convention)
- Returns `{:ok, result}` | `{:error, reason}`

**Layer 2: Thin Wrapper (Namigator.Map)**
- Struct wrapping NIF resource reference
- Position type: `{float, float, float}` tuples
- No processes - apps decide their own concurrency model
- Fine's ResourcePtr handles cleanup on GC

## Public API

```elixir
# Create a map (loads .map file, initializes nav mesh)
{:ok, map} = Namigator.Map.new("/path/to/data", "Kalimdor")

# Pathfinding
{:ok, path} = Namigator.Map.find_path(map, {x1, y1, z1}, {x2, y2, z2})
# => {:ok, [{x1, y1, z1}, ..., {x2, y2, z2}]}

# Spatial queries
true = Namigator.Map.line_of_sight?(map, start, stop, doodads: false)
{:ok, {zone, area}} = Namigator.Map.get_zone_and_area(map, {x, y, z})
{:ok, point} = Namigator.Map.find_random_point_around_circle(map, center, radius)
{:ok, point} = Namigator.Map.find_point_between(map, start, stop, distance)

# ADT management
{:ok, count} = Namigator.Map.load_all_adts(map)
{:ok, {adt_x, adt_y}} = Namigator.Map.load_adt_at(map, x, y)
:ok = Namigator.Map.unload_adt(map, adt_x, adt_y)
{:ok, height} = Namigator.Map.find_height(map, source, x, y)
{:ok, heights} = Namigator.Map.find_heights(map, x, y)
```

## NIF Implementation

```elixir
# lib/namigator/nif.ex
defmodule Namigator.NIF do
  @moduledoc false

  @on_load :load_nif
  def load_nif do
    path = :filename.join(:code.priv_dir(:namigator), ~c"namigator_nif")
    :erlang.load_nif(path, 0)
  end

  # Resource management
  def map_new(_data_path, _map_name), do: :erlang.nif_error(:not_loaded)

  # ADT loading
  def load_all_adts(_map_ref), do: :erlang.nif_error(:not_loaded)
  def load_adt(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)
  def load_adt_at(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)
  def unload_adt(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)
  def adt_loaded?(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)

  # Pathfinding
  def find_path(_map_ref, _x1, _y1, _z1, _x2, _y2, _z2), do: :erlang.nif_error(:not_loaded)
  def find_height(_map_ref, _x1, _y1, _z1, _x2, _y2), do: :erlang.nif_error(:not_loaded)
  def find_heights(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)

  # Spatial queries
  def line_of_sight(_map_ref, _x1, _y1, _z1, _x2, _y2, _z2, _doodads), do: :erlang.nif_error(:not_loaded)
  def get_zone_and_area(_map_ref, _x, _y, _z), do: :erlang.nif_error(:not_loaded)
  def find_random_point_around_circle(_map_ref, _x, _y, _z, _radius), do: :erlang.nif_error(:not_loaded)
  def find_point_between(_map_ref, _x1, _y1, _z1, _x2, _y2, _z2, _distance), do: :erlang.nif_error(:not_loaded)
end
```

## C++ Fine NIF

```cpp
// c_src/namigator_nif.cpp
#include <fine.hpp>
#include "namigator/pathfind/Map.hpp"
#include "namigator/Common.hpp"

// Register Map as a Fine resource (ref-counted, auto-freed)
FINE_RESOURCE(pathfind::Map);

// Create a new map resource
fine::ResourcePtr<pathfind::Map> map_new(
    ErlNifEnv* env,
    std::string data_path,
    std::string map_name
) {
    try {
        return fine::make_resource<pathfind::Map>(data_path, map_name);
    } catch (const std::exception& e) {
        fine::throw_exception(env, e.what());
    }
}

// Pathfinding - returns list of {x, y, z} tuples
fine::Term find_path(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x1, float y1, float z1,
    float x2, float y2, float z2
) {
    std::vector<math::Vertex> path;
    math::Vertex start{x1, y1, z1};
    math::Vertex end{x2, y2, z2};

    if (!map->FindPath(start, end, path, false)) {
        return fine::encode(env, fine::Atom("error"));
    }

    std::vector<std::tuple<float, float, float>> result;
    result.reserve(path.size());
    for (const auto& v : path) {
        result.emplace_back(v.X, v.Y, v.Z);
    }
    return fine::encode(env, result);
}

// Line of sight check
bool line_of_sight(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x1, float y1, float z1,
    float x2, float y2, float z2,
    bool doodads
) {
    return map->LineOfSight({x1, y1, z1}, {x2, y2, z2}, doodads);
}

FINE_NIF(map_new, FINE_DIRTY_CPU);
FINE_NIF(find_path, 0);
FINE_NIF(line_of_sight, 0);
// ... remaining functions

FINE_INIT("Elixir.Namigator.NIF");
```

## Thin Wrapper

```elixir
# lib/namigator/map.ex
defmodule Namigator.Map do
  @moduledoc """
  A loaded navigation map. Wraps a NIF resource reference.

  This is a simple struct - no process, no supervision.
  Consuming applications decide their own concurrency model.
  """

  @enforce_keys [:ref]
  defstruct [:ref]

  @type t :: %__MODULE__{ref: reference()}
  @type position :: {float(), float(), float()}

  @spec new(String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def new(data_path, map_name) do
    case Namigator.NIF.map_new(data_path, map_name) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref}}
      {:error, _} = err -> err
    end
  end

  @spec find_path(t(), position(), position()) :: {:ok, [position()]} | {:error, term()}
  def find_path(%__MODULE__{ref: ref}, {x1, y1, z1}, {x2, y2, z2}) do
    Namigator.NIF.find_path(ref, x1, y1, z1, x2, y2, z2)
  end

  @spec line_of_sight?(t(), position(), position(), keyword()) :: boolean()
  def line_of_sight?(%__MODULE__{ref: ref}, {x1, y1, z1}, {x2, y2, z2}, opts \\ []) do
    doodads = Keyword.get(opts, :doodads, false)
    Namigator.NIF.line_of_sight(ref, x1, y1, z1, x2, y2, z2, doodads)
  end

  @spec load_adt_at(t(), float(), float()) :: {:ok, {integer(), integer()}} | {:error, term()}
  def load_adt_at(%__MODULE__{ref: ref}, x, y) do
    Namigator.NIF.load_adt_at(ref, x, y)
  end

  @spec load_all_adts(t()) :: {:ok, integer()} | {:error, term()}
  def load_all_adts(%__MODULE__{ref: ref}) do
    Namigator.NIF.load_all_adts(ref)
  end

  @spec get_zone_and_area(t(), position()) :: {:ok, {integer(), integer()}} | {:error, term()}
  def get_zone_and_area(%__MODULE__{ref: ref}, {x, y, z}) do
    Namigator.NIF.get_zone_and_area(ref, x, y, z)
  end

  @spec find_random_point_around_circle(t(), position(), float()) :: {:ok, position()} | {:error, term()}
  def find_random_point_around_circle(%__MODULE__{ref: ref}, {x, y, z}, radius) do
    Namigator.NIF.find_random_point_around_circle(ref, x, y, z, radius)
  end
end
```

## Build System

```elixir
# mix.exs
defmodule Namigator.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourname/namigator"

  def project do
    [
      app: :namigator,
      version: @version,
      elixir: "~> 1.15",
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["clean"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.8", runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "c_src", "priv/.gitkeep", "Makefile", "mix.exs", "README.md"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
```

## Vendored Dependencies

Include only what's needed for runtime pathfinding:

| Component | Source | Purpose |
|-----------|--------|---------|
| `namigator/pathfind/` | namigator repo | Core pathfinding API |
| `namigator/utility/` | namigator repo | Math helpers (Vector, Matrix, BVH) |
| `namigator/Common.hpp` | namigator repo | Shared types |
| `recastnavigation/Detour/` | recastnavigation repo | Nav mesh queries |
| `fine/` | elixir-nx/fine | NIF helper library |

**Not included:**
- MapBuilder (mesh generation)
- parser (MPQ/ADT parsing)
- Recast (mesh generation)
- stormlib (MPQ reading)

## Migration from thistle_tea

Current thistle_tea usage:
```elixir
# Before (Rustler, global state, map_id integers)
ThistleTea.Native.Namigator.load("/path/to/maps")
ThistleTea.Native.Namigator.find_path(0, x1, y1, z1, x2, y2, z2)
```

After (Fine, per-map resources):
```elixir
# After
{:ok, kalimdor} = Namigator.Map.new("/path/to/maps", "Kalimdor")
Namigator.Map.find_path(kalimdor, {x1, y1, z1}, {x2, y2, z2})
```

thistle_tea can wrap `Namigator.Map` in its own GenServer if needed.
