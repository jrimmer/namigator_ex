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

## Critical Design Considerations

### Thread Safety

**The underlying `pathfind::Map` C++ class is NOT thread-safe.** From `Map.hpp`:

> "instances of this type are assumed to be thread-local, therefore the type is not thread safe"

**Implications for Elixir consumers:**
- Multiple Elixir processes calling NIF functions on the same map resource concurrently will cause undefined behavior
- Consuming applications MUST serialize access to a map resource (e.g., via GenServer)
- Alternatively, each process can maintain its own map resource (higher memory usage)

**Recommended pattern for consumers:**
```elixir
defmodule MyApp.MapServer do
  use GenServer

  def find_path(server, start, stop) do
    GenServer.call(server, {:find_path, start, stop})
  end

  def handle_call({:find_path, start, stop}, _from, %{map: map} = state) do
    result = Namigator.Map.find_path(map, start, stop)
    {:reply, result, state}
  end
end
```

### Coordinate System

This library uses the World of Warcraft coordinate system:
- **X-axis**: East-West (positive = East)
- **Y-axis**: North-South (positive = North)
- **Z-axis**: Vertical (positive = Up)

All coordinate tuples are `{x, y, z}` in this order.

### Memory Characteristics

- Each map resource loads navigation mesh data into memory
- ADT loading is incremental - only loaded tiles consume memory
- `load_all_adts/1` can consume significant memory for large continents (Kalimdor, Eastern Kingdoms)
- Models (WMO, doodads) are reference-counted and shared across tiles
- Resources are automatically freed when the Elixir term is garbage collected

### Resource Exhaustion Considerations

- No built-in limits on number of maps or ADTs loaded
- Consuming applications should implement their own limits if needed
- Consider using `load_adt/3` for on-demand loading rather than `load_all_adts/1`

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
│       ├── nif.ex                   # Low-level bindings with typespecs
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
- Validates `map_name` to prevent path traversal attacks
- Uses dirty CPU schedulers for potentially slow operations
- Returns `{:ok, result}` | `{:error, reason}` consistently
- Full typespecs for all functions

**Layer 2: Thin Wrapper (Namigator.Map)**
- Struct wrapping NIF resource reference
- Position type: `{float, float, float}` tuples
- No processes - apps decide their own concurrency model
- Fine's ResourcePtr handles cleanup on GC
- Documents thread safety requirements

## Public API

```elixir
# Create a map (loads .map file, initializes nav mesh)
{:ok, map} = Namigator.Map.new("/path/to/data", "Kalimdor")

# Pathfinding
{:ok, path} = Namigator.Map.find_path(map, {x1, y1, z1}, {x2, y2, z2})
# => {:ok, [{x1, y1, z1}, ..., {x2, y2, z2}]}

# Spatial queries
true = Namigator.Map.line_of_sight?(map, start, stop, include_doodads: false)
{:ok, {zone, area}} = Namigator.Map.zone_and_area(map, {x, y, z})
{:ok, point} = Namigator.Map.find_random_point_around_circle(map, center, radius)
{:ok, point} = Namigator.Map.find_point_in_between(map, start, stop, distance)

# ADT management
{:ok, count} = Namigator.Map.load_all_adts(map)
true = Namigator.Map.load_adt(map, x, y)
:ok = Namigator.Map.unload_adt(map, x, y)
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

  @type map_ref :: reference()
  @type coord :: {float(), float(), float()}

  # Resource management
  @spec map_new(String.t(), String.t()) :: map_ref()
  def map_new(_data_path, _map_name), do: :erlang.nif_error(:not_loaded)

  # ADT loading
  @spec map_load_all_adts(map_ref()) :: integer()
  def map_load_all_adts(_map_ref), do: :erlang.nif_error(:not_loaded)

  @spec map_load_adt(map_ref(), integer(), integer()) :: boolean()
  def map_load_adt(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)

  @spec map_unload_adt(map_ref(), integer(), integer()) :: :ok
  def map_unload_adt(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)

  @spec map_has_adt(map_ref(), integer(), integer()) :: boolean()
  def map_has_adt(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)

  @spec map_is_adt_loaded(map_ref(), integer(), integer()) :: boolean()
  def map_is_adt_loaded(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)

  # Pathfinding
  @spec map_find_path(map_ref(), coord(), coord(), boolean()) ::
          {:ok, [coord()]} | {:error, :no_path}
  def map_find_path(_map_ref, _start, _stop, _allow_partial), do: :erlang.nif_error(:not_loaded)

  @spec map_find_height(map_ref(), coord(), float(), float()) ::
          {:ok, float()} | {:error, :not_found}
  def map_find_height(_map_ref, _source, _x, _y), do: :erlang.nif_error(:not_loaded)

  @spec map_find_heights(map_ref(), float(), float()) ::
          {:ok, [float()]} | {:error, :not_found}
  def map_find_heights(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)

  # Spatial queries
  @spec map_line_of_sight(map_ref(), coord(), coord(), boolean()) :: boolean()
  def map_line_of_sight(_map_ref, _start, _stop, _include_doodads), do: :erlang.nif_error(:not_loaded)

  @spec map_zone_and_area(map_ref(), coord()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, :not_found}
  def map_zone_and_area(_map_ref, _position), do: :erlang.nif_error(:not_loaded)

  @spec map_find_random_point_around_circle(map_ref(), coord(), float()) ::
          {:ok, coord()} | {:error, :not_found}
  def map_find_random_point_around_circle(_map_ref, _center, _radius), do: :erlang.nif_error(:not_loaded)

  @spec map_find_point_in_between(map_ref(), coord(), coord(), float()) ::
          {:ok, coord()} | {:error, :not_found}
  def map_find_point_in_between(_map_ref, _start, _stop, _distance), do: :erlang.nif_error(:not_loaded)
end
```

## C++ Fine NIF

```cpp
// c_src/namigator_nif.cpp
#include <fine.hpp>
#include "pathfind/Map.hpp"

#include <regex>

// Register Map as a Fine resource (ref-counted, auto-freed)
FINE_RESOURCE(pathfind::Map);

// Validate map_name to prevent path traversal
bool validate_map_name(const std::string& name) {
    // Only allow alphanumeric, underscore, and hyphen
    static const std::regex valid_pattern("^[a-zA-Z0-9_-]+$");
    return std::regex_match(name, valid_pattern) &&
           name.find("..") == std::string::npos;
}

// Create a new map resource (dirty CPU - file I/O)
fine::ResourcePtr<pathfind::Map> map_new(
    ErlNifEnv* env,
    std::string data_path,
    std::string map_name
) {
    if (!validate_map_name(map_name)) {
        fine::throw_exception(env, "invalid map name: must be alphanumeric, underscore, or hyphen only");
    }
    return fine::make_resource<pathfind::Map>(data_path, map_name);
}

// Load all ADTs (dirty CPU - slow file I/O)
int64_t map_load_all_adts(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map) {
    return map->LoadAllADTs();
}

// Find path (dirty CPU - potentially expensive computation)
std::variant<fine::Ok<Path>, fine::Error<fine::Atom>> map_find_path(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    Coord start, Coord end,
    bool allow_partial
) {
    // ... implementation
}

// Use FINE_DIRTY_CPU for potentially slow operations
FINE_NIF(map_new, FINE_DIRTY_CPU);
FINE_NIF(map_load_all_adts, FINE_DIRTY_CPU);
FINE_NIF(map_load_adt, FINE_DIRTY_CPU);
FINE_NIF(map_find_path, FINE_DIRTY_CPU);
FINE_NIF(map_find_height, FINE_DIRTY_CPU);
FINE_NIF(map_find_heights, FINE_DIRTY_CPU);
FINE_NIF(map_line_of_sight, FINE_DIRTY_CPU);
FINE_NIF(map_zone_and_area, 0);  // Fast lookup, normal scheduler OK
FINE_NIF(map_find_random_point_around_circle, FINE_DIRTY_CPU);
FINE_NIF(map_find_point_in_between, FINE_DIRTY_CPU);

// Fast operations can use normal scheduler
FINE_NIF(map_unload_adt, 0);
FINE_NIF(map_has_adt, 0);
FINE_NIF(map_is_adt_loaded, 0);

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

  ## Thread Safety

  **WARNING:** The underlying C++ Map class is NOT thread-safe.

  If multiple Elixir processes access the same `Namigator.Map` struct
  concurrently, you MUST serialize access (e.g., via a GenServer).

  Alternatively, each process can create its own map instance, at the
  cost of increased memory usage.

  ## Coordinate System

  All coordinates use the World of Warcraft coordinate system:
  - X: East-West (positive = East)
  - Y: North-South (positive = North)
  - Z: Vertical (positive = Up)
  """

  # ... implementation
end
```

## Error Handling

All functions return consistent result types:

| Function | Success | Error |
|----------|---------|-------|
| `new/2` | `{:ok, map}` | `{:error, reason}` |
| `find_path/3,4` | `{:ok, path}` | `{:error, :no_path}` |
| `find_height/4` | `{:ok, z}` | `{:error, :not_found}` |
| `find_heights/3` | `{:ok, [z, ...]}` | `{:error, :not_found}` |
| `zone_and_area/2` | `{:ok, {zone, area}}` | `{:error, :not_found}` |
| `load_all_adts/1` | `{:ok, count}` | `{:error, reason}` |
| `load_adt/3` | `true` / `false` | (no error case) |
| `line_of_sight?/3,4` | `true` / `false` | (no error case) |

## Build System

```elixir
# mix.exs
defmodule Namigator.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jrimmer/namigator_ex"

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
      package: package(),
      description: "Elixir bindings for the namigator pathfinding library (World of Warcraft navigation meshes)",
      source_url: @source_url,
      docs: docs()
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
      files: ["lib", "c_src", "priv/.gitkeep", "Makefile", "mix.exs", "README.md", "LICENSE"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Your Name"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
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

## Security Considerations

1. **Path Traversal**: `map_name` is validated to contain only alphanumeric characters, underscores, and hyphens. This prevents attempts to access files outside the data directory.

2. **Resource Exhaustion**: No built-in limits on map/ADT loading. Consuming applications should implement their own rate limiting or resource caps if exposed to untrusted input.

3. **Input Validation**: Coordinate values are not validated for NaN/Infinity - the underlying C++ code handles this gracefully by returning error results.
