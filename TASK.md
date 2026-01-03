# TASK.md - Code Review Tasks

Last reviewed: 2026-01-03

## 🔴 Critical Priority

_No critical issues found._

## 🟠 High Priority

- [ ] **[ROBUSTNESS]** Add validation for radius and distance parameters
  - Files: `c_src/namigator_nif.cpp:169-206`
  - `find_random_point_around_circle` and `find_point_in_between` accept any float
  - Negative radius values could cause unexpected behavior in Detour

- [ ] **[ERROR-HANDLING]** Handle NIF load failure gracefully in application startup
  - File: `lib/namigator/nif.ex:9-16`
  - `load_nif/0` can return `{:error, reason}` but no fallback or crash handling
  - Consider: Log error, raise descriptive exception, or implement retry logic

## 🟡 Medium Priority

- [ ] **[TESTING]** Add unit tests for remaining input validation edge cases
  - File: `test/namigator_nif_test.exs`
  - Test very large numbers, NaN/Infinity floats
  - ADT coordinate bounds testing is complete (0-63 validation)

- [ ] **[TESTING]** Add property-based tests for coordinate handling
  - Consider using StreamData for property-based testing of coordinate transforms
  - Verify float->double->float conversion maintains precision

- [ ] **[CONSISTENCY]** Standardize error handling across all Map functions
  - File: `lib/namigator/map.ex`
  - `load_adt/3` returns boolean, `load_all_adts/1` returns `{:ok, count}` or `{:error, reason}`
  - `unload_adt/3` returns `:ok` without error case
  - Consider: Make all functions return consistent `{:ok, value} | {:error, reason}` tuples

- [ ] **[DOCS]** Add @doc for module-level type definitions
  - File: `lib/namigator/nif.ex:6-7`
  - Types `map_ref` and `coord` are defined but not documented
  - Consider: Add `@typedoc` for each type

- [ ] **[TESTING]** Add tests for error message content validation
  - File: `test/namigator_nif_test.exs`
  - Current tests check that errors are raised but not the specific error messages
  - Better error message assertions would prevent regressions

- [ ] **[BUILD]** Add Linux-specific compiler flag handling
  - File: `Makefile:61-66`
  - Only Darwin and default (Linux) are handled
  - Consider: Add explicit Linux detection and flags for musl/glibc compatibility

- [ ] **[MEMORY]** Document memory usage patterns and add guidance for large maps
  - File: `lib/namigator/map.ex` moduledoc
  - Add estimates for memory per ADT
  - Document when to use `unload_adt/3` for memory management

## 🟢 Low Priority

- [ ] **[DOCS]** Create CHANGELOG.md for version tracking
  - Required for proper hex.pm package releases
  - Document breaking changes, features, and fixes per version

- [ ] **[DOCS]** Add @since tags to functions
  - Track when each function was added for API stability

- [ ] **[CLEANUP]** Remove or document the `test_add` function
  - Files: `c_src/namigator_nif.cpp:208-211`, `lib/namigator/nif.ex:18-20`
  - This appears to be a development test function
  - Either remove before release or mark as `@doc false` explicitly

- [ ] **[STYLE]** Add Credo for static analysis
  - Add `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` to deps
  - Configure `.credo.exs` for consistent code style

- [ ] **[STYLE]** Add Dialyzer for static type checking
  - Add `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}` to deps
  - Leverage existing typespecs for compile-time type checking

- [ ] **[BUILD]** Add GitHub Actions CI workflow
  - Run tests on multiple Elixir/OTP versions
  - Run on multiple platforms (Linux, macOS)
  - Verify NIF compilation succeeds

- [ ] **[DOCS]** Improve README with troubleshooting section
  - Common build issues (missing compiler, wrong C++ standard)
  - Debug tips for NIF load failures
  - Platform-specific notes (M1 Mac, musl Linux)

- [ ] **[TESTING]** Add benchmark tests for pathfinding performance
  - Use Benchee to measure pathfinding speed
  - Track performance regressions across versions

## Completed

- [x] **[SECURITY]** Add path traversal validation for map_name parameter
- [x] **[SECURITY]** Add data_path validation in map_new to prevent path traversal
- [x] **[ROBUSTNESS]** Add bounds checking for ADT grid coordinates (0-63)
- [x] **[PERFORMANCE]** Use dirty CPU schedulers for long-running NIFs
- [x] **[DOCS]** Add thread safety warning to Map module documentation
- [x] **[DOCS]** Document coordinate system in Map module
- [x] **[TYPES]** Add typespecs to NIF module functions
- [x] **[PACKAGE]** Add maintainers and links to mix.exs package config
