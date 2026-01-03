// c_src/namigator_nif.cpp
#include <fine.hpp>
#include "pathfind/Map.hpp"

// Type aliases for coordinate tuples
using Coord = std::tuple<double, double, double>;
using Path = std::vector<Coord>;

// Register the Map resource type
FINE_RESOURCE(pathfind::Map);

// Create a new Map resource
fine::ResourcePtr<pathfind::Map> map_new(ErlNifEnv* env, std::string data_path, std::string map_name) {
    return fine::make_resource<pathfind::Map>(data_path, map_name);
}

// Load all ADTs for a map, return count loaded
int64_t map_load_all_adts(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map) {
    return map->LoadAllADTs();
}

// Load a specific ADT
bool map_load_adt(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map, int64_t x, int64_t y) {
    return map->LoadADT(static_cast<int>(x), static_cast<int>(y));
}

// Unload a specific ADT
fine::Atom map_unload_adt(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map, int64_t x, int64_t y) {
    map->UnloadADT(static_cast<int>(x), static_cast<int>(y));
    return fine::Atom("ok");
}

// Check if ADT exists
bool map_has_adt(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map, int64_t x, int64_t y) {
    return map->HasADT(static_cast<int>(x), static_cast<int>(y));
}

// Check if ADT is loaded
bool map_is_adt_loaded(ErlNifEnv* env, fine::ResourcePtr<pathfind::Map> map, int64_t x, int64_t y) {
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

FINE_NIF(test_add, 0);
FINE_NIF(map_new, 0);
FINE_NIF(map_load_all_adts, 0);
FINE_NIF(map_load_adt, 0);
FINE_NIF(map_unload_adt, 0);
FINE_NIF(map_has_adt, 0);
FINE_NIF(map_is_adt_loaded, 0);
FINE_NIF(map_find_path, 0);
FINE_NIF(map_find_height, 0);
FINE_NIF(map_find_heights, 0);
FINE_NIF(map_line_of_sight, 0);
FINE_NIF(map_zone_and_area, 0);
FINE_NIF(map_find_random_point_around_circle, 0);
FINE_NIF(map_find_point_in_between, 0);

FINE_INIT("Elixir.Namigator.NIF");
