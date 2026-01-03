defmodule Namigator.NIFTest do
  use ExUnit.Case, async: true

  alias Namigator.NIF

  describe "NIF loading" do
    test "NIF module is loaded successfully" do
      assert Code.ensure_loaded?(NIF)
    end

    test "test_add function works correctly" do
      assert NIF.test_add(2, 3) == 5
    end

    test "test_add with negative numbers" do
      assert NIF.test_add(-5, 3) == -2
      assert NIF.test_add(5, -3) == 2
      assert NIF.test_add(-5, -3) == -8
    end

    test "test_add with zero" do
      assert NIF.test_add(0, 0) == 0
      assert NIF.test_add(0, 5) == 5
      assert NIF.test_add(5, 0) == 5
    end

    test "test_add with large numbers" do
      assert NIF.test_add(1_000_000, 2_000_000) == 3_000_000
    end
  end

  describe "map_new/2" do
    test "raises error for non-existent path" do
      assert_raise RuntimeError, fn ->
        NIF.map_new("/non/existent/path", "TestMap")
      end
    end

    test "accepts string arguments and raises for invalid path" do
      assert_raise RuntimeError, fn ->
        NIF.map_new("some/path", "MapName")
      end
    end
  end

  describe "map_new/2 data_path validation" do
    test "rejects empty data path" do
      assert_raise RuntimeError, ~r/invalid data path/, fn ->
        NIF.map_new("", "MapName")
      end
    end

    test "rejects relative data path" do
      assert_raise RuntimeError, ~r/invalid data path/, fn ->
        NIF.map_new("relative/path", "MapName")
      end
    end

    test "rejects data path with double dots" do
      assert_raise RuntimeError, ~r/invalid data path/, fn ->
        NIF.map_new("/some/../etc", "MapName")
      end
    end

    test "accepts valid absolute data path" do
      # Should fail for different reason (path doesn't exist), not validation
      try do
        NIF.map_new("/valid/absolute/path", "MapName")
        flunk("Expected an error to be raised")
      rescue
        e in RuntimeError ->
          refute Exception.message(e) =~ "invalid data path"
      end
    end
  end

  describe "map_new/2 map_name validation" do
    test "rejects map names with double dots" do
      assert_raise RuntimeError, ~r/invalid map name/, fn ->
        NIF.map_new("/some/path", "../etc/passwd")
      end
    end

    test "rejects map names with forward slashes" do
      assert_raise RuntimeError, ~r/invalid map name/, fn ->
        NIF.map_new("/some/path", "foo/bar")
      end
    end

    test "rejects map names with backslashes" do
      assert_raise RuntimeError, ~r/invalid map name/, fn ->
        NIF.map_new("/some/path", "foo\\bar")
      end
    end

    test "rejects empty map names" do
      assert_raise RuntimeError, ~r/invalid map name/, fn ->
        NIF.map_new("/some/path", "")
      end
    end

    test "rejects map names with spaces" do
      assert_raise RuntimeError, ~r/invalid map name/, fn ->
        NIF.map_new("/some/path", "map with spaces")
      end
    end

    test "rejects map names with special characters" do
      assert_raise RuntimeError, ~r/invalid map name/, fn ->
        NIF.map_new("/some/path", "map@name!")
      end
    end

    test "accepts valid map names with alphanumeric characters" do
      # This will still fail because the path doesn't exist,
      # but it should fail for a different reason (not "invalid map name")
      try do
        NIF.map_new("/some/path", "Azeroth123")
        flunk("Expected an error to be raised")
      rescue
        e in RuntimeError ->
          refute Exception.message(e) =~ "invalid map name"
      end
    end

    test "accepts valid map names with underscores" do
      try do
        NIF.map_new("/some/path", "Eastern_Kingdoms")
        flunk("Expected an error to be raised")
      rescue
        e in RuntimeError ->
          refute Exception.message(e) =~ "invalid map name"
      end
    end

    test "accepts valid map names with hyphens" do
      try do
        NIF.map_new("/some/path", "map-name")
        flunk("Expected an error to be raised")
      rescue
        e in RuntimeError ->
          refute Exception.message(e) =~ "invalid map name"
      end
    end
  end

  describe "ADT coordinate bounds validation" do
    # ADT grid is 64x64, valid range is 0-63
    # We can't test with a real map, but we can verify the error is raised
    # before the map operations fail for other reasons

    test "map_load_adt rejects negative x coordinate" do
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        # Create a fake ref - validation happens before map access
        NIF.map_load_adt(make_ref(), -1, 32)
      end
    end

    test "map_load_adt rejects x coordinate above 63" do
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        NIF.map_load_adt(make_ref(), 64, 32)
      end
    end

    test "map_load_adt rejects negative y coordinate" do
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        NIF.map_load_adt(make_ref(), 32, -1)
      end
    end

    test "map_load_adt rejects y coordinate above 63" do
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        NIF.map_load_adt(make_ref(), 32, 64)
      end
    end

    test "map_has_adt rejects out-of-bounds coordinates" do
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        NIF.map_has_adt(make_ref(), 100, 100)
      end
    end

    test "map_is_adt_loaded rejects out-of-bounds coordinates" do
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        NIF.map_is_adt_loaded(make_ref(), -5, 70)
      end
    end

    test "map_unload_adt rejects out-of-bounds coordinates" do
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        NIF.map_unload_adt(make_ref(), 64, 0)
      end
    end
  end

  describe "ADT coordinate bounds edge cases" do
    # Test boundary values (0 and 63 should be valid, pass validation but fail on NIF)
    # Fine raises ArgumentError with "decode failed" for invalid resource refs

    test "map_load_adt accepts coordinate 0 (fails on NIF, not validation)" do
      # Coordinate 0 is valid, so validation passes but NIF fails with different error
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        NIF.map_load_adt(make_ref(), 0, 0)
      end
    end

    test "map_load_adt accepts coordinate 63 (fails on NIF, not validation)" do
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        NIF.map_load_adt(make_ref(), 63, 63)
      end
    end

    test "map_has_adt accepts boundary coordinates" do
      # These pass validation but fail because make_ref() isn't a valid map
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        NIF.map_has_adt(make_ref(), 0, 63)
      end
    end

    test "map_is_adt_loaded accepts boundary coordinates" do
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        NIF.map_is_adt_loaded(make_ref(), 63, 0)
      end
    end

    test "map_unload_adt accepts boundary coordinates" do
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        NIF.map_unload_adt(make_ref(), 0, 63)
      end
    end

    test "map_load_adt rejects non-integer x coordinate" do
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        NIF.map_load_adt(make_ref(), 1.5, 32)
      end
    end

    test "map_load_adt rejects non-integer y coordinate" do
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        NIF.map_load_adt(make_ref(), 32, 1.5)
      end
    end
  end

  describe "NIF function stubs exist" do
    # Use __info__(:functions) which is more reliable than function_exported?
    # after NIFs have been loaded
    @exported_functions NIF.__info__(:functions)

    test "map_load_all_adts/1 stub exists" do
      assert {:map_load_all_adts, 1} in @exported_functions
    end

    test "map_load_adt/3 stub exists" do
      assert {:map_load_adt, 3} in @exported_functions
    end

    test "map_unload_adt/3 stub exists" do
      assert {:map_unload_adt, 3} in @exported_functions
    end

    test "map_has_adt/3 stub exists" do
      assert {:map_has_adt, 3} in @exported_functions
    end

    test "map_is_adt_loaded/3 stub exists" do
      assert {:map_is_adt_loaded, 3} in @exported_functions
    end

    test "map_find_path/4 stub exists" do
      assert {:map_find_path, 4} in @exported_functions
    end

    test "map_find_height/4 stub exists" do
      assert {:map_find_height, 4} in @exported_functions
    end

    test "map_find_heights/3 stub exists" do
      assert {:map_find_heights, 3} in @exported_functions
    end

    test "map_line_of_sight/4 stub exists" do
      assert {:map_line_of_sight, 4} in @exported_functions
    end

    test "map_zone_and_area/2 stub exists" do
      assert {:map_zone_and_area, 2} in @exported_functions
    end

    test "map_find_random_point_around_circle/3 stub exists" do
      assert {:map_find_random_point_around_circle, 3} in @exported_functions
    end

    test "map_find_point_in_between/4 stub exists" do
      assert {:map_find_point_in_between, 4} in @exported_functions
    end
  end
end
