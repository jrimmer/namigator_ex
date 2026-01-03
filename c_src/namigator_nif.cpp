// c_src/namigator_nif.cpp
#include <fine.hpp>
#include "pathfind/Map.hpp"

#include <algorithm>
#include <cctype>

// Type aliases for coordinate tuples
using Coord = std::tuple<double, double, double>;
using Path = std::vector<Coord>;

// Register the Map resource type
FINE_RESOURCE(pathfind::Map);

// Validate map_name to prevent path traversal attacks
// Only allows alphanumeric characters, underscores, and hyphens
static bool validate_map_name(const std::string& name) {
    if (name.empty()) return false;

    // Check for path traversal attempts
    if (name.find("..") != std::string::npos) return false;
    if (name.find('/') != std::string::npos) return false;
    if (name.find('\\') != std::string::npos) return false;

    // Only allow alphanumeric, underscore, and hyphen
    return std::all_of(name.begin(), name.end(), [](char c) {
        return std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '-';
    });
}

// Validate data_path to prevent path traversal attacks
static bool validate_data_path(const std::string& path) {
    if (path.empty()) return false;

    // Must be an absolute path
    if (path[0] != '/') return false;

    // Check for path traversal attempts
    if (path.find("..") != std::string::npos) return false;

    return true;
}

// ADT grid bounds (0-63 for 64x64 grid)
static constexpr int ADT_MIN = 0;
static constexpr int ADT_MAX = 63;

// Create a new Map resource
// Uses dirty CPU scheduler since it involves file I/O
fine::ResourcePtr<pathfind::Map> map_new(ErlNifEnv* env, std::string data_path, std::string map_name) {
    if (!validate_data_path(data_path)) {
        throw std::runtime_error("invalid data path: must be an absolute path without '..' sequences");
    }
    if (!validate_map_name(map_name)) {
        throw std::runtime_error("invalid map name: must contain only alphanumeric characters, underscores, or hyphens");
    }
    return fine::make_resource<pathfind::Map>(data_path, map_name);
}

// Load all ADTs for a map, return count loaded
int64_t map_load_all_adts(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map) {
    return map->LoadAllADTs();
}

// Validate ADT coordinates are within bounds
static void validate_adt_coords(int64_t x, int64_t y) {
    if (x < ADT_MIN || x > ADT_MAX || y < ADT_MIN || y > ADT_MAX) {
        throw std::invalid_argument("ADT coordinates must be between 0 and 63");
    }
}

// Load a specific ADT (called from Elixir wrapper that validates coords)
bool map_load_adt_nif(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map, int64_t x, int64_t y) {
    validate_adt_coords(x, y);
    return map->LoadADT(static_cast<int>(x), static_cast<int>(y));
}

// Unload a specific ADT (called from Elixir wrapper that validates coords)
fine::Atom map_unload_adt_nif(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map, int64_t x, int64_t y) {
    validate_adt_coords(x, y);
    map->UnloadADT(static_cast<int>(x), static_cast<int>(y));
    return fine::Atom("ok");
}

// Check if ADT exists (called from Elixir wrapper that validates coords)
bool map_has_adt_nif(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map, int64_t x, int64_t y) {
    validate_adt_coords(x, y);
    return map->HasADT(static_cast<int>(x), static_cast<int>(y));
}

// Check if ADT is loaded (called from Elixir wrapper that validates coords)
bool map_is_adt_loaded_nif(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map, int64_t x, int64_t y) {
    validate_adt_coords(x, y);
    return map->IsADTLoaded(static_cast<int>(x), static_cast<int>(y));
}

// Find path between two points
// Returns {:ok, [{x, y, z}, ...]} on success, {:error, :no_path} on failure
std::variant<fine::Ok<Path>, fine::Error<fine::Atom>> map_find_path(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    Coord start,
    Coord end,
    bool allow_partial
) {
    auto [sx, sy, sz] = start;
    auto [ex, ey, ez] = end;

    math::Vector3 start_pos{static_cast<float>(sx), static_cast<float>(sy), static_cast<float>(sz)};
    math::Vector3 end_pos{static_cast<float>(ex), static_cast<float>(ey), static_cast<float>(ez)};

    std::vector<math::Vector3> output;

    if (map->FindPath(start_pos, end_pos, output, allow_partial)) {
        Path result;
        result.reserve(output.size());
        for (const auto& p : output) {
            result.emplace_back(static_cast<double>(p.X), static_cast<double>(p.Y), static_cast<double>(p.Z));
        }
        return fine::Ok(result);
    } else {
        return fine::Error(fine::Atom("no_path"));
    }
}

// Find height at position from a source point (scenario 1: walking to point)
std::variant<fine::Ok<double>, fine::Error<fine::Atom>> map_find_height(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    Coord source,
    double x,
    double y
) {
    auto [sx, sy, sz] = source;
    math::Vector3 src{static_cast<float>(sx), static_cast<float>(sy), static_cast<float>(sz)};

    float z;
    if (map->FindHeight(src, static_cast<float>(x), static_cast<float>(y), z)) {
        return fine::Ok(static_cast<double>(z));
    } else {
        return fine::Error(fine::Atom("not_found"));
    }
}

// Find all heights at a given (x, y) position (scenario 2: all possible z values)
std::variant<fine::Ok<std::vector<double>>, fine::Error<fine::Atom>> map_find_heights(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    double x,
    double y
) {
    std::vector<float> heights;
    if (map->FindHeights(static_cast<float>(x), static_cast<float>(y), heights)) {
        std::vector<double> result;
        result.reserve(heights.size());
        for (float h : heights) {
            result.push_back(static_cast<double>(h));
        }
        return fine::Ok(result);
    } else {
        return fine::Error(fine::Atom("not_found"));
    }
}

// Check line of sight between two points
bool map_line_of_sight(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    Coord start,
    Coord stop,
    bool include_doodads
) {
    auto [sx, sy, sz] = start;
    auto [ex, ey, ez] = stop;

    math::Vector3 start_pos{static_cast<float>(sx), static_cast<float>(sy), static_cast<float>(sz)};
    math::Vector3 end_pos{static_cast<float>(ex), static_cast<float>(ey), static_cast<float>(ez)};

    return map->LineOfSight(start_pos, end_pos, include_doodads);
}

// Get zone and area ID at a position
std::variant<fine::Ok<uint64_t, uint64_t>, fine::Error<fine::Atom>> map_zone_and_area(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    Coord position
) {
    auto [x, y, z] = position;
    math::Vector3 pos{static_cast<float>(x), static_cast<float>(y), static_cast<float>(z)};

    unsigned int zone, area;
    if (map->ZoneAndArea(pos, zone, area)) {
        return fine::Ok(static_cast<uint64_t>(zone), static_cast<uint64_t>(area));
    } else {
        return fine::Error(fine::Atom("not_found"));
    }
}

// Find a random point around a circle
std::variant<fine::Ok<Coord>, fine::Error<fine::Atom>> map_find_random_point_around_circle(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    Coord center,
    double radius
) {
    auto [cx, cy, cz] = center;
    math::Vector3 center_pos{static_cast<float>(cx), static_cast<float>(cy), static_cast<float>(cz)};

    math::Vector3 result;
    if (map->FindRandomPointAroundCircle(center_pos, static_cast<float>(radius), result)) {
        return fine::Ok(Coord{static_cast<double>(result.X), static_cast<double>(result.Y), static_cast<double>(result.Z)});
    } else {
        return fine::Error(fine::Atom("not_found"));
    }
}

// Find a point at a specific distance between two points
std::variant<fine::Ok<Coord>, fine::Error<fine::Atom>> map_find_point_in_between(
    ErlNifEnv* env,
    fine::ResourcePtr<pathfind::Map> map,
    Coord start,
    Coord end,
    double distance
) {
    auto [sx, sy, sz] = start;
    auto [ex, ey, ez] = end;

    math::Vector3 start_pos{static_cast<float>(sx), static_cast<float>(sy), static_cast<float>(sz)};
    math::Vector3 end_pos{static_cast<float>(ex), static_cast<float>(ey), static_cast<float>(ez)};

    math::Vector3 result;
    if (map->FindPointInBetweenVectors(start_pos, end_pos, static_cast<float>(distance), result)) {
        return fine::Ok(Coord{static_cast<double>(result.X), static_cast<double>(result.Y), static_cast<double>(result.Z)});
    } else {
        return fine::Error(fine::Atom("not_found"));
    }
}

// Test function
int64_t test_add(ErlNifEnv* env, int64_t a, int64_t b) {
    return a + b;
}

// Test function - fast, use normal scheduler
FINE_NIF(test_add, 0);

// Map creation - involves file I/O, use dirty CPU scheduler
FINE_NIF(map_new, ERL_NIF_DIRTY_JOB_CPU_BOUND);

// ADT loading/unloading - involves file I/O, use dirty CPU scheduler
FINE_NIF(map_load_all_adts, ERL_NIF_DIRTY_JOB_CPU_BOUND);
FINE_NIF(map_load_adt_nif, ERL_NIF_DIRTY_JOB_CPU_BOUND);
FINE_NIF(map_unload_adt_nif, ERL_NIF_DIRTY_JOB_CPU_BOUND);

// ADT queries - fast lookups, use normal scheduler
FINE_NIF(map_has_adt_nif, 0);
FINE_NIF(map_is_adt_loaded_nif, 0);

// Pathfinding - potentially expensive computation, use dirty CPU scheduler
FINE_NIF(map_find_path, ERL_NIF_DIRTY_JOB_CPU_BOUND);
FINE_NIF(map_find_height, ERL_NIF_DIRTY_JOB_CPU_BOUND);
FINE_NIF(map_find_heights, ERL_NIF_DIRTY_JOB_CPU_BOUND);
FINE_NIF(map_line_of_sight, ERL_NIF_DIRTY_JOB_CPU_BOUND);

// Zone/area lookup - fast hash lookup, use normal scheduler
FINE_NIF(map_zone_and_area, ERL_NIF_DIRTY_JOB_CPU_BOUND);

// Spatial queries - can involve pathfinding, use dirty CPU scheduler
FINE_NIF(map_find_random_point_around_circle, ERL_NIF_DIRTY_JOB_CPU_BOUND);
FINE_NIF(map_find_point_in_between, ERL_NIF_DIRTY_JOB_CPU_BOUND);

FINE_INIT("Elixir.Namigator.NIF");
