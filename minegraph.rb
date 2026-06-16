ENode = Struct.new(:f, :children)  # (string, list of ids)

class EGraph
  attr_accessor :parent

  def initialize
    @parent = []
  end

  def makeset
    result = parent.length
    parent << result
    result
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

  def to_graphviz
    edges = []
    parent.each_with_index do |p, i|
      edges << "#{i} -> #{p};"
    end
    "digraph G {\n#{edges.join("\n")}\n}"
  end
end

egraph = EGraph.new
a = egraph.makeset
b = egraph.makeset
c = egraph.makeset
egraph.union(a, b)
puts egraph.to_graphviz
egraph.union(b, c)
puts egraph.to_graphviz

require "minitest/autorun"

class TestEGraph < Minitest::Test
  def test_union_find
    g = EGraph.new
    v1 = g.makeset
    v2 = g.makeset
    v3 = g.makeset
    assert_equal(v1, g.find(v1))
    assert_equal(v2, g.find(v2))
    assert_equal(v3, g.find(v3))
    g.union(v1, v2)
    assert_equal(g.find(v1), g.find(v2))
    refute_equal(g.find(v1), g.find(v3))
  end

  def test_union_find_is_transitive
    g = EGraph.new
    v1 = g.makeset
    v2 = g.makeset
    v3 = g.makeset
    g.union(v1, v2)
    g.union(v2, v3)
    assert_equal(g.find(v1), g.find(v3))
  end
end
