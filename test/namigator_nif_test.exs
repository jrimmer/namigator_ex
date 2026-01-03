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
