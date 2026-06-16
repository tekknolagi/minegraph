ENode = Struct.new(:f, :children)  # (string, list of ids)

class EGraph
  attr_accessor :parent

  def initialize
    @parent = {}
  end

  def makeset(x)
    raise if parent.key?(x)
    parent[x] = x
  end

  def find(x)
    result = x
    while parent[result] != result
      result = parent[result]
    end
    result
  end

  def union(x, y)
    x = find(x)
    y = find(y)
    if x != y
      parent[y] = x
    end
  end
end

require "minitest/autorun"

class TestEGraph < Minitest::Test
  def test_union_find
    g = EGraph.new
    g.makeset(1)
    g.makeset(2)
    g.makeset(3)
    assert_equal(1, g.find(1))
    assert_equal(2, g.find(2))
    assert_equal(3, g.find(3))
    g.union(1, 2)
    assert_equal(g.find(1), g.find(2))
    refute_equal(g.find(1), g.find(3))
  end

  def test_union_find_is_transitive
    g = EGraph.new
    g.makeset(1)
    g.makeset(2)
    g.makeset(3)
    g.union(1, 2)
    g.union(2, 3)
    assert_equal(g.find(1), g.find(3))
  end
end
