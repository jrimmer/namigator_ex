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

    test "unload_adt/3 raises for out-of-bounds coordinates" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/ADT coordinates must be between 0 and 63/, fn ->
        Map.unload_adt(map, -1, 64)
      end
    end

    test "load_adt/3 accepts valid boundary coordinates (0)" do
      # Valid coordinates pass validation but fail on invalid ref
      # Fine raises ArgumentError with "decode failed" for invalid resource refs
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.load_adt(map, 0, 0)
      end
    end

    test "load_adt/3 accepts valid boundary coordinates (63)" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.load_adt(map, 63, 63)
      end
    end
  end

  describe "error handling with invalid refs" do
    # All functions should handle invalid map refs gracefully
    # Fine raises ArgumentError with "decode failed" for invalid resource refs

    test "find_path/4 raises on invalid ref" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.find_path(map, {0.0, 0.0, 0.0}, {1.0, 1.0, 1.0})
      end
    end

    test "find_height/4 raises on invalid ref" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.find_height(map, {0.0, 0.0, 0.0}, 1.0, 1.0)
      end
    end

    test "find_heights/3 raises on invalid ref" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.find_heights(map, 0.0, 0.0)
      end
    end

    test "line_of_sight?/4 raises on invalid ref" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.line_of_sight?(map, {0.0, 0.0, 0.0}, {1.0, 1.0, 1.0})
      end
    end

    test "zone_and_area/2 raises on invalid ref" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.zone_and_area(map, {0.0, 0.0, 0.0})
      end
    end

    test "find_random_point_around_circle/3 raises on invalid ref" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.find_random_point_around_circle(map, {0.0, 0.0, 0.0}, 10.0)
      end
    end

    test "find_point_in_between/4 raises on invalid ref" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.find_point_in_between(map, {0.0, 0.0, 0.0}, {1.0, 1.0, 1.0}, 0.5)
      end
    end

    test "has_adt?/3 raises on invalid ref with valid coords" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.has_adt?(map, 32, 32)
      end
    end

    test "adt_loaded?/3 raises on invalid ref with valid coords" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.adt_loaded?(map, 32, 32)
      end
    end

    test "unload_adt/3 raises on invalid ref with valid coords" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.unload_adt(map, 32, 32)
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

    test "find_path with allow_partial option" do
      map = %Map{ref: make_ref()}
      # Should accept the option but fail on invalid ref
      # Fine raises ArgumentError with "decode failed" for invalid resource refs
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.find_path(map, {0.0, 0.0, 0.0}, {1.0, 1.0, 1.0}, allow_partial: true)
      end
    end

    test "line_of_sight? with include_doodads option" do
      map = %Map{ref: make_ref()}
      assert_raise ArgumentError, ~r/decode failed/, fn ->
        Map.line_of_sight?(map, {0.0, 0.0, 0.0}, {1.0, 1.0, 1.0}, include_doodads: false)
      end
    end
  end

  describe "data path validation" do
    test "rejects relative paths" do
      {:error, reason} = Map.new("relative/path", "MapName")
      assert reason =~ "invalid data path"
    end

    test "rejects paths with path traversal" do
      {:error, reason} = Map.new("/some/../path", "MapName")
      assert reason =~ "invalid data path"
    end

    test "rejects empty paths" do
      {:error, reason} = Map.new("", "MapName")
      assert reason =~ "invalid data path"
    end
  end

  describe "map name validation" do
    test "rejects names with forward slashes" do
      {:error, reason} = Map.new("/valid/path", "bad/name")
      assert reason =~ "invalid map name"
    end

    test "rejects names with backslashes" do
      {:error, reason} = Map.new("/valid/path", "bad\\name")
      assert reason =~ "invalid map name"
    end

    test "rejects empty names" do
      {:error, reason} = Map.new("/valid/path", "")
      assert reason =~ "invalid map name"
    end

    test "rejects names with special characters" do
      {:error, reason} = Map.new("/valid/path", "map@name!")
      assert reason =~ "invalid map name"
    end

    test "accepts valid names with underscores" do
      # Valid name, invalid path - should fail for path reason
      {:error, reason} = Map.new("/valid/path", "valid_name")
      refute reason =~ "invalid map name"
    end

    test "accepts valid names with hyphens" do
      {:error, reason} = Map.new("/valid/path", "valid-name")
      refute reason =~ "invalid map name"
    end

    test "accepts valid alphanumeric names" do
      {:error, reason} = Map.new("/valid/path", "Azeroth123")
      refute reason =~ "invalid map name"
    end
  end

  describe "normalize_error/1 behavior" do
    # Test error normalization through Map.new

    test "returns string error message for RuntimeError" do
      {:error, reason} = Map.new("/nonexistent/path", "ValidMap")
      assert is_binary(reason)
      assert reason != ""
    end

    test "returns string error message for validation errors" do
      {:error, reason} = Map.new("/some/path", "invalid map name with spaces")
      assert is_binary(reason)
      assert reason =~ "invalid map name"
    end
  end
end
