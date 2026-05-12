require "test_helper"

class EnumerableDeepCompactBlankTest < ActiveSupport::TestCase
  test "Hash#deep_compact_blank! removes blank values at every depth" do
    hash = {
      a: "keep",
      b: nil,
      c: "",
      d: { e: nil, f: "keep", g: { h: "", i: "keep" } },
      j: [ nil, "", "keep" ]
    }

    compacted = {
      a: "keep",
      d: { f: "keep", g: { i: "keep" } },
      j: [ "keep" ]
    }

    hash.deep_compact_blank!

    assert_equal compacted, hash
  end

  test "Hash#deep_compact_blank! drops a hash that becomes empty after pruning" do
    hash = { a: "keep", b: { c: nil, d: "" }, e: [ nil ] }
    compacted = { a: "keep" }

    hash.deep_compact_blank!

    assert_equal compacted, hash
  end

  test "Array#deep_compact_blank! removes blanks across nested arrays and hashes" do
    array = [ "keep", nil, "", { a: nil, b: "keep" }, [ nil, "", "keep" ], [ nil ] ]
    compacted = [ "keep", { b: "keep" }, [ "keep" ] ]

    array.deep_compact_blank!

    assert_equal compacted, array
  end

  test "Enumerable#deep_compact_blank does not mutate the receiver" do
    original = { a: nil, b: "keep", c: { d: "" } }
    expected = original.deep_dup
    compacted = { b: "keep" }

    result = original.deep_compact_blank

    assert_equal compacted, result
    assert_equal expected, original
  end

  test "Enumerable#deep_compact_blank returns a duplicated array" do
    original = [ nil, "keep", [ "", "inner" ] ]
    expected = original.deep_dup
    compacted = [ "keep", [ "inner" ] ]

    result = original.deep_compact_blank

    assert_equal compacted, result
    assert_equal expected, original
  end

  test "leaves non-enumerable values untouched" do
    object = Object.new
    hash = { a: object, b: nil }
    compacted = { a: object }

    hash.deep_compact_blank!

    assert_equal compacted, hash
  end
end
