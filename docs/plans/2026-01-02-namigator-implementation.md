# Namigator Elixir Port Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a standalone hex package that provides Elixir bindings to the namigator C++ pathfinding library using Fine NIFs.

**Architecture:** Fine NIF wrapping namigator's pathfind library, with a thin Elixir struct wrapper. No OTP patterns - consuming apps decide their own process model.

**Tech Stack:** Elixir 1.15+, Fine (C++ NIF), elixir_make, namigator C++ (vendored)

---

## Task 1: Project Scaffolding

**Files:**
- Create: `mix.exs`
- Create: `.formatter.exs`
- Create: `.gitignore`
- Create: `lib/namigator.ex`
- Create: `priv/.gitkeep`

**Step 1: Create mix.exs**

```elixir
# mix.exs
defmodule Namigator.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/namigator-ex/namigator"

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
      description: "Elixir bindings for namigator pathfinding library",
      source_url: @source_url
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
      links: %{"GitHub" => @source_url}
    ]
  end
end
```

**Step 2: Create .formatter.exs**

```elixir
# .formatter.exs
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

**Step 3: Create .gitignore**

```
# .gitignore
/_build/
/cover/
/deps/
/doc/
/.fetch
erl_crash.dump
*.ez
*.beam
/config/*.secret.exs
.elixir_ls/

# NIF artifacts
/priv/*.so
/priv/*.dll
*.o
*.a

# C++ build artifacts
/c_src/**/*.o
/c_src/namigator/build/
/c_src/recastnavigation/build/
```

**Step 4: Create lib/namigator.ex**

```elixir
# lib/namigator.ex
defmodule Namigator do
  @moduledoc """
  Elixir bindings for the namigator pathfinding library.

  See `Namigator.Map` for the main API.
  """
end
```

**Step 5: Create priv/.gitkeep**

```
# Empty file to ensure priv directory exists
```

**Step 6: Verify project compiles**

Run: `mix deps.get && mix compile`
Expected: Compilation succeeds (no NIF yet, just Elixir)

**Step 7: Commit**

```bash
git add mix.exs .formatter.exs .gitignore lib/namigator.ex priv/.gitkeep
git commit -m "chore: initial project scaffolding"
```

---

## Task 2: Vendor Fine Headers

**Files:**
- Create: `c_src/fine/` (clone from elixir-nx/fine)

**Step 1: Create c_src directory**

```bash
mkdir -p c_src
```

**Step 2: Clone Fine and extract headers**

```bash
git clone --depth 1 https://github.com/elixir-nx/fine.git /tmp/fine
cp -r /tmp/fine/c_src/fine c_src/fine
rm -rf /tmp/fine
```

**Step 3: Verify Fine headers exist**

Run: `ls c_src/fine/`
Expected: Should see `fine.hpp` and related headers

**Step 4: Commit**

```bash
git add c_src/fine/
git commit -m "chore: vendor Fine NIF headers"
```

---

## Task 3: Vendor Namigator C++ Source

**Files:**
- Create: `c_src/namigator/` (subset of namigator repo)

**Step 1: Copy pathfind library**

```bash
mkdir -p c_src/namigator
cp -r ../namigator/pathfind c_src/namigator/
cp -r ../namigator/utility c_src/namigator/
cp ../namigator/Common.hpp c_src/namigator/
```

**Step 2: Copy Detour from recastnavigation**

```bash
mkdir -p c_src/recastnavigation/Detour
cp -r ../namigator/recastnavigation/Detour/Include c_src/recastnavigation/Detour/
cp -r ../namigator/recastnavigation/Detour/Source c_src/recastnavigation/Detour/
```

**Step 3: Verify files exist**

Run: `ls c_src/namigator/pathfind/`
Expected: Map.cpp, Map.hpp, Tile.cpp, etc.

Run: `ls c_src/recastnavigation/Detour/Include/`
Expected: DetourNavMesh.h, DetourNavMeshQuery.h, etc.

**Step 4: Commit**

```bash
git add c_src/namigator/ c_src/recastnavigation/
git commit -m "chore: vendor namigator and Detour source"
```

---

## Task 4: Create Makefile

**Files:**
- Create: `Makefile`

**Step 1: Write Makefile**

```makefile
# Makefile
PRIV_DIR = priv
NIF_SO = $(PRIV_DIR)/namigator_nif.so

# Erlang include path
ERL_INCLUDE = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

# Source files
NIF_SRC = c_src/namigator_nif.cpp

NAMIGATOR_SRCS = \
	c_src/namigator/pathfind/Map.cpp \
	c_src/namigator/pathfind/Tile.cpp \
	c_src/namigator/pathfind/BVH.cpp \
	c_src/namigator/pathfind/TemporaryObstacle.cpp \
	c_src/namigator/utility/AABBTree.cpp \
	c_src/namigator/utility/BinaryStream.cpp \
	c_src/namigator/utility/BoundingBox.cpp \
	c_src/namigator/utility/MathHelper.cpp \
	c_src/namigator/utility/Matrix.cpp \
	c_src/namigator/utility/Quaternion.cpp \
	c_src/namigator/utility/Ray.cpp \
	c_src/namigator/utility/String.cpp \
	c_src/namigator/utility/Vector.cpp

DETOUR_SRCS = \
	c_src/recastnavigation/Detour/Source/DetourAlloc.cpp \
	c_src/recastnavigation/Detour/Source/DetourCommon.cpp \
	c_src/recastnavigation/Detour/Source/DetourNavMesh.cpp \
	c_src/recastnavigation/Detour/Source/DetourNavMeshBuilder.cpp \
	c_src/recastnavigation/Detour/Source/DetourNavMeshQuery.cpp \
	c_src/recastnavigation/Detour/Source/DetourNode.cpp

ALL_SRCS = $(NIF_SRC) $(NAMIGATOR_SRCS) $(DETOUR_SRCS)
ALL_OBJS = $(ALL_SRCS:.cpp=.o)

# Compiler flags
CXX = c++
CXXFLAGS = -O3 -std=c++17 -fPIC -Wall
CXXFLAGS += -I$(ERL_INCLUDE)
CXXFLAGS += -Ic_src/fine
CXXFLAGS += -Ic_src/namigator
CXXFLAGS += -Ic_src

# Platform-specific flags
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	LDFLAGS = -undefined dynamic_lookup -dynamiclib
	NIF_SO = $(PRIV_DIR)/namigator_nif.so
else
	LDFLAGS = -shared
endif

.PHONY: all clean

all: $(NIF_SO)

$(NIF_SO): $(ALL_OBJS)
	@mkdir -p $(PRIV_DIR)
	$(CXX) $(LDFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

clean:
	rm -f $(NIF_SO) $(ALL_OBJS)
```

**Step 2: Test Makefile syntax**

Run: `make -n`
Expected: Shows compilation commands without errors

**Step 3: Commit**

```bash
git add Makefile
git commit -m "build: add Makefile for NIF compilation"
```

---

## Task 5: Create NIF Stub

**Files:**
- Create: `c_src/namigator_nif.cpp`
- Create: `lib/namigator/nif.ex`

**Step 1: Write minimal NIF C++ file**

```cpp
// c_src/namigator_nif.cpp
#include <fine.hpp>

int64_t test_add(ErlNifEnv* env, int64_t a, int64_t b) {
    return a + b;
}

FINE_NIF(test_add, 0);
FINE_INIT("Elixir.Namigator.NIF");
```

**Step 2: Write NIF Elixir module**

```elixir
# lib/namigator/nif.ex
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
```

**Step 3: Build the NIF**

Run: `mix compile`
Expected: Compiles C++ and produces `priv/namigator_nif.so`

**Step 4: Test the NIF loads**

Run: `mix run -e "IO.inspect Namigator.NIF.test_add(2, 3)"`
Expected: Outputs `5`

**Step 5: Commit**

```bash
git add c_src/namigator_nif.cpp lib/namigator/nif.ex
git commit -m "feat: add minimal NIF stub with test_add function"
```

---

## Task 6: Implement Map Resource

**Files:**
- Modify: `c_src/namigator_nif.cpp`
- Modify: `lib/namigator/nif.ex`

**Step 1: Update NIF to create Map resource**

```cpp
// c_src/namigator_nif.cpp
#include <fine.hpp>
#include "namigator/pathfind/Map.hpp"
#include "namigator/Common.hpp"
#include <string>
#include <stdexcept>

// Register Map as a Fine resource
FINE_RESOURCE(pathfind::Map);

fine::ResourcePtr<pathfind::Map> map_new(
    ErlNifEnv* env,
    std::string data_path,
    std::string map_name
) {
    try {
        return fine::make_resource<pathfind::Map>(data_path, map_name);
    } catch (const std::exception& e) {
        return fine::raise<fine::ResourcePtr<pathfind::Map>>(env, e.what());
    }
}

FINE_NIF(map_new, FINE_DIRTY_CPU);
FINE_INIT("Elixir.Namigator.NIF");
```

**Step 2: Update Elixir NIF module**

```elixir
# lib/namigator/nif.ex
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

  def map_new(_data_path, _map_name), do: :erlang.nif_error(:not_loaded)
end
```

**Step 3: Rebuild**

Run: `mix clean && mix compile`
Expected: Compiles without errors

**Step 4: Commit**

```bash
git add c_src/namigator_nif.cpp lib/namigator/nif.ex
git commit -m "feat: add map_new NIF for creating Map resources"
```

---

## Task 7: Implement find_path NIF

**Files:**
- Modify: `c_src/namigator_nif.cpp`
- Modify: `lib/namigator/nif.ex`

**Step 1: Add find_path to NIF**

```cpp
// Add to c_src/namigator_nif.cpp after map_new

fine::Ok<std::vector<std::tuple<float, float, float>>> find_path(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x1, float y1, float z1,
    float x2, float y2, float z2
) {
    std::vector<math::Vertex> path;
    math::Vertex start{x1, y1, z1};
    math::Vertex end{x2, y2, z2};

    try {
        if (!map->FindPath(start, end, path, false)) {
            return fine::Error("path_not_found");
        }

        std::vector<std::tuple<float, float, float>> result;
        result.reserve(path.size());
        for (const auto& v : path) {
            result.emplace_back(v.X, v.Y, v.Z);
        }
        return fine::Ok(result);
    } catch (const std::exception& e) {
        return fine::Error(e.what());
    }
}

FINE_NIF(find_path, 0);
```

**Step 2: Add to Elixir NIF module**

```elixir
# Add to lib/namigator/nif.ex
def find_path(_map_ref, _x1, _y1, _z1, _x2, _y2, _z2), do: :erlang.nif_error(:not_loaded)
```

**Step 3: Rebuild and verify**

Run: `mix clean && mix compile`
Expected: Compiles without errors

**Step 4: Commit**

```bash
git add c_src/namigator_nif.cpp lib/namigator/nif.ex
git commit -m "feat: add find_path NIF"
```

---

## Task 8: Implement Remaining NIFs

**Files:**
- Modify: `c_src/namigator_nif.cpp`
- Modify: `lib/namigator/nif.ex`

**Step 1: Add all remaining NIFs to C++**

Add the following functions to `c_src/namigator_nif.cpp`:

```cpp
// ADT management
fine::Ok<int32_t> load_all_adts(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map
) {
    try {
        int32_t count = map->LoadAllADTs();
        return fine::Ok(count);
    } catch (const std::exception& e) {
        return fine::Error(e.what());
    }
}

fine::Ok<std::tuple<int32_t, int32_t>> load_adt_at(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x, float y
) {
    try {
        int adt_x = 0, adt_y = 0;
        math::Convert::WorldToAdt({x, y, 0.f}, adt_x, adt_y);

        if (!map->HasADT(adt_x, adt_y)) {
            return fine::Error("no_adt_at_location");
        }
        if (!map->LoadADT(adt_x, adt_y)) {
            return fine::Error("failed_to_load_adt");
        }
        return fine::Ok(std::make_tuple(adt_x, adt_y));
    } catch (const std::exception& e) {
        return fine::Error(e.what());
    }
}

fine::Ok<> unload_adt(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    int32_t x, int32_t y
) {
    try {
        map->UnloadADT(x, y);
        return fine::Ok();
    } catch (const std::exception& e) {
        return fine::Error(e.what());
    }
}

bool adt_loaded(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    int32_t x, int32_t y
) {
    return map->IsADTLoaded(x, y);
}

// Spatial queries
bool line_of_sight(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x1, float y1, float z1,
    float x2, float y2, float z2,
    bool doodads
) {
    try {
        return map->LineOfSight({x1, y1, z1}, {x2, y2, z2}, doodads);
    } catch (...) {
        return false;
    }
}

fine::Ok<std::tuple<uint32_t, uint32_t>> get_zone_and_area(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x, float y, float z
) {
    try {
        unsigned int zone = 0, area = 0;
        if (!map->ZoneAndArea({x, y, z}, zone, area)) {
            return fine::Error("unknown_zone_and_area");
        }
        return fine::Ok(std::make_tuple(zone, area));
    } catch (const std::exception& e) {
        return fine::Error(e.what());
    }
}

fine::Ok<std::tuple<float, float, float>> find_random_point_around_circle(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x, float y, float z,
    float radius
) {
    try {
        math::Vertex result;
        if (!map->FindRandomPointAroundCircle({x, y, z}, radius, result)) {
            return fine::Error("no_random_point_found");
        }
        return fine::Ok(std::make_tuple(result.X, result.Y, result.Z));
    } catch (const std::exception& e) {
        return fine::Error(e.what());
    }
}

fine::Ok<std::tuple<float, float, float>> find_point_between(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x1, float y1, float z1,
    float x2, float y2, float z2,
    float distance
) {
    try {
        math::Vertex result;
        if (!map->FindPointInBetweenVectors({x1, y1, z1}, {x2, y2, z2}, distance, result)) {
            return fine::Error("no_point_found");
        }
        return fine::Ok(std::make_tuple(result.X, result.Y, result.Z));
    } catch (const std::exception& e) {
        return fine::Error(e.what());
    }
}

fine::Ok<float> find_height(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x1, float y1, float z1,
    float x2, float y2
) {
    try {
        float result;
        if (!map->FindHeight({x1, y1, z1}, x2, y2, result)) {
            return fine::Error("unknown_height");
        }
        return fine::Ok(result);
    } catch (const std::exception& e) {
        return fine::Error(e.what());
    }
}

fine::Ok<std::vector<float>> find_heights(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    float x, float y
) {
    try {
        std::vector<float> heights;
        if (!map->FindHeights(x, y, heights)) {
            return fine::Error("no_heights_found");
        }
        return fine::Ok(heights);
    } catch (const std::exception& e) {
        return fine::Error(e.what());
    }
}

// Register all NIFs
FINE_NIF(load_all_adts, FINE_DIRTY_CPU);
FINE_NIF(load_adt_at, FINE_DIRTY_CPU);
FINE_NIF(unload_adt, 0);
FINE_NIF(adt_loaded, 0);
FINE_NIF(line_of_sight, 0);
FINE_NIF(get_zone_and_area, 0);
FINE_NIF(find_random_point_around_circle, 0);
FINE_NIF(find_point_between, 0);
FINE_NIF(find_height, 0);
FINE_NIF(find_heights, 0);
```

**Step 2: Add all stubs to Elixir NIF module**

```elixir
# lib/namigator/nif.ex - complete file
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

  # Map creation
  def map_new(_data_path, _map_name), do: :erlang.nif_error(:not_loaded)

  # ADT management
  def load_all_adts(_map_ref), do: :erlang.nif_error(:not_loaded)
  def load_adt_at(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)
  def unload_adt(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)
  def adt_loaded(_map_ref, _x, _y), do: :erlang.nif_error(:not_loaded)

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

**Step 3: Rebuild**

Run: `mix clean && mix compile`
Expected: Compiles without errors

**Step 4: Commit**

```bash
git add c_src/namigator_nif.cpp lib/namigator/nif.ex
git commit -m "feat: implement all NIF functions"
```

---

## Task 9: Create Map Wrapper Module

**Files:**
- Create: `lib/namigator/map.ex`

**Step 1: Write the Map module**

```elixir
# lib/namigator/map.ex
defmodule Namigator.Map do
  @moduledoc """
  A loaded navigation map. Wraps a NIF resource reference.

  This is a simple struct - no process, no supervision.
  Consuming applications decide their own concurrency model.

  ## Example

      {:ok, map} = Namigator.Map.new("/path/to/data", "Kalimdor")
      {:ok, path} = Namigator.Map.find_path(map, {-8949.0, -132.0, 83.0}, {-8900.0, -100.0, 80.0})

  """

  @enforce_keys [:ref]
  defstruct [:ref]

  @type t :: %__MODULE__{ref: reference()}
  @type position :: {float(), float(), float()}

  @doc """
  Creates a new map from the given data path and map name.

  The data path should contain pre-generated navigation mesh files.
  The map name corresponds to the directory name (e.g., "Kalimdor", "EasternKingdoms").
  """
  @spec new(String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def new(data_path, map_name) when is_binary(data_path) and is_binary(map_name) do
    case Namigator.NIF.map_new(data_path, map_name) do
      ref when is_reference(ref) -> {:ok, %__MODULE__{ref: ref}}
      {:error, _} = err -> err
    end
  end

  @doc """
  Finds a path between two positions.

  Returns a list of waypoints from start to stop.
  """
  @spec find_path(t(), position(), position()) :: {:ok, [position()]} | {:error, term()}
  def find_path(%__MODULE__{ref: ref}, {x1, y1, z1}, {x2, y2, z2}) do
    Namigator.NIF.find_path(ref, x1, y1, z1, x2, y2, z2)
  end

  @doc """
  Checks if there is line of sight between two positions.

  ## Options

    * `:doodads` - Whether to include doodads in the check (default: `false`)

  """
  @spec line_of_sight?(t(), position(), position(), keyword()) :: boolean()
  def line_of_sight?(%__MODULE__{ref: ref}, {x1, y1, z1}, {x2, y2, z2}, opts \\ []) do
    doodads = Keyword.get(opts, :doodads, false)
    Namigator.NIF.line_of_sight(ref, x1, y1, z1, x2, y2, z2, doodads)
  end

  @doc """
  Loads the ADT tile at the given world coordinates.

  Returns the ADT grid coordinates on success.
  """
  @spec load_adt_at(t(), float(), float()) :: {:ok, {integer(), integer()}} | {:error, term()}
  def load_adt_at(%__MODULE__{ref: ref}, x, y) do
    Namigator.NIF.load_adt_at(ref, x, y)
  end

  @doc """
  Loads all ADT tiles for the map.

  Returns the number of ADTs loaded.
  """
  @spec load_all_adts(t()) :: {:ok, integer()} | {:error, term()}
  def load_all_adts(%__MODULE__{ref: ref}) do
    Namigator.NIF.load_all_adts(ref)
  end

  @doc """
  Unloads the ADT tile at the given grid coordinates.
  """
  @spec unload_adt(t(), integer(), integer()) :: :ok | {:error, term()}
  def unload_adt(%__MODULE__{ref: ref}, x, y) do
    case Namigator.NIF.unload_adt(ref, x, y) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, _} = err -> err
    end
  end

  @doc """
  Checks if the ADT tile at the given grid coordinates is loaded.
  """
  @spec adt_loaded?(t(), integer(), integer()) :: boolean()
  def adt_loaded?(%__MODULE__{ref: ref}, x, y) do
    Namigator.NIF.adt_loaded(ref, x, y)
  end

  @doc """
  Gets the zone and area IDs for the given position.
  """
  @spec get_zone_and_area(t(), position()) :: {:ok, {zone :: integer(), area :: integer()}} | {:error, term()}
  def get_zone_and_area(%__MODULE__{ref: ref}, {x, y, z}) do
    Namigator.NIF.get_zone_and_area(ref, x, y, z)
  end

  @doc """
  Finds a random point within the given radius of the center position.
  """
  @spec find_random_point_around_circle(t(), position(), float()) :: {:ok, position()} | {:error, term()}
  def find_random_point_around_circle(%__MODULE__{ref: ref}, {x, y, z}, radius) do
    Namigator.NIF.find_random_point_around_circle(ref, x, y, z, radius)
  end

  @doc """
  Finds a point at the given distance along the line between start and stop.
  """
  @spec find_point_between(t(), position(), position(), float()) :: {:ok, position()} | {:error, term()}
  def find_point_between(%__MODULE__{ref: ref}, {x1, y1, z1}, {x2, y2, z2}, distance) do
    Namigator.NIF.find_point_between(ref, x1, y1, z1, x2, y2, z2, distance)
  end

  @doc """
  Finds the height at the target position, given a starting position for context.
  """
  @spec find_height(t(), position(), float(), float()) :: {:ok, float()} | {:error, term()}
  def find_height(%__MODULE__{ref: ref}, {x1, y1, z1}, x2, y2) do
    Namigator.NIF.find_height(ref, x1, y1, z1, x2, y2)
  end

  @doc """
  Finds all possible heights at the given x, y coordinates.
  """
  @spec find_heights(t(), float(), float()) :: {:ok, [float()]} | {:error, term()}
  def find_heights(%__MODULE__{ref: ref}, x, y) do
    Namigator.NIF.find_heights(ref, x, y)
  end
end
```

**Step 2: Verify compilation**

Run: `mix compile`
Expected: Compiles without warnings

**Step 3: Commit**

```bash
git add lib/namigator/map.ex
git commit -m "feat: add Namigator.Map wrapper module"
```

---

## Task 10: Add Tests

**Files:**
- Create: `test/test_helper.exs`
- Create: `test/namigator_test.exs`

**Step 1: Create test helper**

```elixir
# test/test_helper.exs
ExUnit.start()
```

**Step 2: Create basic tests**

```elixir
# test/namigator_test.exs
defmodule NamigatorTest do
  use ExUnit.Case, async: true

  # Note: These tests require pre-generated map data.
  # Skip if no test data is available.

  @moduletag :integration

  @data_path System.get_env("NAMIGATOR_TEST_DATA", "./test/fixtures/maps")

  describe "Namigator.Map.new/2" do
    @tag :skip
    test "creates a map from valid data" do
      assert {:ok, %Namigator.Map{}} = Namigator.Map.new(@data_path, "Kalimdor")
    end

    test "returns error for invalid path" do
      assert {:error, _reason} = Namigator.Map.new("/nonexistent/path", "Kalimdor")
    end
  end

  describe "NIF loading" do
    test "NIF module loads successfully" do
      # If this doesn't crash, the NIF loaded
      assert function_exported?(Namigator.NIF, :map_new, 2)
    end
  end
end
```

**Step 3: Run tests**

Run: `mix test`
Expected: Tests pass (with skipped integration tests)

**Step 4: Commit**

```bash
git add test/
git commit -m "test: add basic test structure"
```

---

## Task 11: Add README and License

**Files:**
- Create: `README.md`
- Create: `LICENSE`

**Step 1: Write README**

```markdown
# Namigator

Elixir bindings for the [namigator](https://github.com/namigator/namigator) pathfinding library.

## Installation

Add `namigator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:namigator, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
# Load a map
{:ok, map} = Namigator.Map.new("/path/to/nav/data", "Kalimdor")

# Load terrain data
{:ok, count} = Namigator.Map.load_all_adts(map)

# Find a path
start = {-8949.0, -132.0, 83.0}
stop = {-8900.0, -100.0, 80.0}
{:ok, path} = Namigator.Map.find_path(map, start, stop)

# Check line of sight
true = Namigator.Map.line_of_sight?(map, start, stop)

# Get zone and area
{:ok, {zone, area}} = Namigator.Map.get_zone_and_area(map, start)
```

## Building

This package includes vendored C++ source code. Building requires:

- Elixir 1.15+
- C++17 compatible compiler (gcc 7+, clang 5+, MSVC 2017+)
- Make

## License

MIT License - see LICENSE file.
```

**Step 2: Write LICENSE**

```
MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Step 3: Commit**

```bash
git add README.md LICENSE
git commit -m "docs: add README and LICENSE"
```

---

## Task 12: Final Integration Test

**Step 1: Clean build**

Run: `mix deps.get && mix clean && mix compile`
Expected: Full compilation succeeds

**Step 2: Run all tests**

Run: `mix test`
Expected: All tests pass

**Step 3: Generate docs**

Run: `mix docs`
Expected: Documentation generated in `doc/`

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: complete initial implementation"
```

---

Plan complete and saved to `docs/plans/2026-01-02-namigator-implementation.md`.

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
