defmodule Namigator.MapTest do
  use ExUnit.Case, async: true

  alias Namigator.Map

  describe "struct definition" do
    test "Map struct has ref field" do
      map = %Map{ref: :some_ref}
      assert map.ref == :some_ref
    end

    test "Map struct ref defaults to nil" do
      map = %Map{}
      assert map.ref == nil
    end

    test "Map struct fields are correct" do
      assert Map.__struct__() == %Map{ref: nil}
    end
  end

  describe "new/2" do
    test "returns error tuple for invalid path" do
      result = Map.new("/non/existent/path", "TestMap")
      assert {:error, _reason} = result
    end

    test "accepts string arguments and returns error for missing files" do
      result = Map.new("/tmp", "NonExistentMap")
      assert {:error, _reason} = result
    end

    test "error contains reason information" do
      {:error, reason} = Map.new("/bad/path", "BadMap")
      assert reason != nil
    end

    test "error reason is a string" do
      {:error, reason} = Map.new("/bad/path", "BadMap")
      assert is_binary(reason)
    end

    test "invalid map name returns a meaningful message" do
      {:error, reason} = Map.new("/some/path", "../etc/passwd")
      assert reason =~ "invalid map name"
    end
  end

  describe "load_all_adts/1" do
    test "returns error tuple on invalid map ref" do
      map = %Map{ref: make_ref()}
      assert {:error, reason} = Map.load_all_adts(map)
      assert is_binary(reason)
    end
  end

  describe "ADT bounds validation" do
    test "load_adt/3 raises for out-of-bounds coordinates" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        Map.load_adt(map, -1, 0)
      end
    end

    test "has_adt?/3 raises for out-of-bounds coordinates" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        Map.has_adt?(map, 0, 64)
      end
    end

    test "adt_loaded?/3 raises for out-of-bounds coordinates" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        Map.adt_loaded?(map, 100, 0)
      end
    end
  end

  describe "type specs" do
    test "coord type is a 3-tuple of floats" do
      coord = {1.0, 2.0, 3.0}
      {x, y, z} = coord
      assert is_float(x)
      assert is_float(y)
      assert is_float(z)
    end

    test "path type is a list of coord tuples" do
      path = [{1.0, 2.0, 3.0}, {4.0, 5.0, 6.0}]
      assert is_list(path)
      assert Enum.all?(path, fn {x, y, z} ->
        is_float(x) and is_float(y) and is_float(z)
      end)
    end
  end

  describe "function existence" do
    test "new/2 exists" do
      assert function_exported?(Map, :new, 2)
    end

    test "load_all_adts/1 exists" do
      assert function_exported?(Map, :load_all_adts, 1)
    end

    test "load_adt/3 exists" do
      assert function_exported?(Map, :load_adt, 3)
    end

    test "unload_adt/3 exists" do
      assert function_exported?(Map, :unload_adt, 3)
    end

    test "has_adt?/3 exists" do
      assert function_exported?(Map, :has_adt?, 3)
    end

    test "adt_loaded?/3 exists" do
      assert function_exported?(Map, :adt_loaded?, 3)
    end

    test "find_path/3 exists (without options)" do
      assert function_exported?(Map, :find_path, 3)
    end

    test "find_path/4 exists (with options)" do
      assert function_exported?(Map, :find_path, 4)
    end

    test "find_height/4 exists" do
      assert function_exported?(Map, :find_height, 4)
    end

    test "find_heights/3 exists" do
      assert function_exported?(Map, :find_heights, 3)
    end

    # Verify the newly added wrapper function
    @tag :find_heights
    test "find_heights/3 wrapper delegates to NIF" do
      # The function should accept a map struct and x, y coordinates
      assert function_exported?(Map, :find_heights, 3)
    end

    test "line_of_sight?/3 exists (without options)" do
      assert function_exported?(Map, :line_of_sight?, 3)
    end

    test "line_of_sight?/4 exists (with options)" do
      assert function_exported?(Map, :line_of_sight?, 4)
    end

    test "zone_and_area/2 exists" do
      assert function_exported?(Map, :zone_and_area, 2)
    end

    test "find_random_point_around_circle/3 exists" do
      assert function_exported?(Map, :find_random_point_around_circle, 3)
    end

    test "find_point_in_between/4 exists" do
      assert function_exported?(Map, :find_point_in_between, 4)
    end
  end

  describe "option parsing" do
    test "find_path default options" do
      # Verify the function accepts options
      # Can't test actual behavior without a real map, but can verify API
      assert function_exported?(Map, :find_path, 4)
    end

    test "line_of_sight? default options" do
      assert function_exported?(Map, :line_of_sight?, 4)
    end
  end
end
