# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-01-03

### Added

- Initial release with Elixir NIF bindings for namigator pathfinding library
- `Namigator.Map` module for high-level map operations
- `Namigator.NIF` module with low-level NIF bindings
- Pathfinding with `find_path/3,4` supporting partial paths
- Height queries with `find_height/4` and `find_heights/3`
- Line of sight checks with `line_of_sight?/3,4`
- Zone and area lookups with `zone_and_area/2`
- Random point generation with `find_random_point_around_circle/3`
- Point interpolation with `find_point_in_between/4`
- ADT (Area Data Tile) management functions
- Path traversal validation for data paths and map names
- ADT coordinate bounds checking (0-63) with defense-in-depth
- Dirty CPU schedulers for I/O-bound NIF operations
- Comprehensive typespecs for all public functions

### Security

- Input validation prevents path traversal attacks via `data_path` and `map_name`
- Decompression bomb protection (512MB limit) in C++ library
- Bounds checking on all coordinate inputs

[Unreleased]: https://github.com/jrimmer/namigator_ex/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jrimmer/namigator_ex/releases/tag/v0.1.0
