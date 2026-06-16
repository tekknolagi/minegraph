class UnionFind
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

ENode = Struct.new(:f, :children)  # (string, list of ids)

uf = UnionFind.new
a = uf.makeset
b = uf.makeset
c = uf.makeset
uf.union(a, b)
puts uf.to_graphviz
uf.union(b, c)
puts uf.to_graphviz

require "minitest/autorun"

class TestUnionFind < Minitest::Test
  def test_union_find
    uf = UnionFind.new
    v1 = uf.makeset
    v2 = uf.makeset
    v3 = uf.makeset
    assert_equal(v1, uf.find(v1))
    assert_equal(v2, uf.find(v2))
    assert_equal(v3, uf.find(v3))
    uf.union(v1, v2)
    assert_equal(uf.find(v1), uf.find(v2))
    refute_equal(uf.find(v1), uf.find(v3))
  end

  def test_union_find_is_transitive
    uf = UnionFind.new
    v1 = uf.makeset
    v2 = uf.makeset
    v3 = uf.makeset
    uf.union(v1, v2)
    uf.union(v2, v3)
    assert_equal(uf.find(v1), uf.find(v3))
  end
end
