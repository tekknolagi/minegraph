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

  # make y point to x. if we make a change, return true. else return false.
  def union(x, y)
    x = find(x)
    y = find(y)
    if x != y
      parent[y] = x
      true
    else
      false
    end
  end

  def equiv?(x, y) = find(x) == find(y)

  def to_graphviz
    edges = []
    parent.each_with_index do |p, i|
      edges << "#{i} -> #{p};"
    end
    "digraph G {\n#{edges.join("\n")}\n}"
  end
end

ENode = Struct.new(:f, :children)  # (string, list of ids)

class EGraph
  attr_accessor :union_find
  attr_accessor :hash_cons

  def initialize
    @union_find = UnionFind.new
    @hash_cons = {}
  end

  def canonicalize_node(node)
    ENode.new(node.f, node.children&.map { union_find.find(it) })
  end

  def add_node(node)
    # Canonicalize
    node = canonicalize_node(node)
    # Intern or make a new set
    result = hash_cons[node]
    return result if result != nil
    result = hash_cons[node] = union_find.makeset
    result
  end

  def rebuild
    changed = true
    while changed
      changed = false
      old_hash_cons = hash_cons
      hash_cons = {}
      old_hash_cons.each do |node, old_id|
        # Like add_node except we're re-using old_id instead of making a new set
        # Canonicalize
        node = canonicalize_node(node)
        old_id = union_find.find(old_id)
        # Intern or insert the old id
        result = hash_cons[node]
        new_id = if result == nil
                   hash_cons[node] = old_id
                 else
                   result
                 end
        # Make sure the old id and new id are the same
        changed |= union(old_id, new_id)
      end
    end
  end

  def union(x, y) = union_find.union(x, y)
  def equiv?(x, y) = union_find.equiv?(x, y)
end

# uf = UnionFind.new
# a = uf.makeset
# b = uf.makeset
# c = uf.makeset
# uf.union(a, b)
# puts uf.to_graphviz
# uf.union(b, c)
# puts uf.to_graphviz

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

class TestEGraph < Minitest::Test
  def test_add_node_returns_new_id
    g = EGraph.new
    v0 = g.add_node(ENode.new(:f))
    assert v0.is_a?(Integer)
  end

  def test_add_node_returns_existing_id
    g = EGraph.new
    v0 = g.add_node(ENode.new(:f))
    v1 = g.add_node(ENode.new(:f))
    assert_equal(v0, v1)
  end

  def test_congruence_closure
    g = EGraph.new
    a = g.add_node(ENode.new(:a))
    b = g.add_node(ENode.new(:b))
    fa = g.add_node(ENode.new(:f, [a]))
    fb = g.add_node(ENode.new(:f, [b]))
    g.union(a, b)
    g.rebuild
    assert(g.equiv?(fa, fb))
  end

  def test_congruence_closure_requiring_successive_rebuilds
    g = EGraph.new
    a = g.add_node(ENode.new(:a))
    fa = g.add_node(ENode.new(:f, [a]))
    ffa = g.add_node(ENode.new(:f, [fa]))
    fffa = g.add_node(ENode.new(:f, [ffa]))
    b = g.add_node(ENode.new(:b))
    fb = g.add_node(ENode.new(:f, [b]))
    ffb = g.add_node(ENode.new(:f, [fb]))
    fffb = g.add_node(ENode.new(:f, [ffb]))
    g.union(a, b)
    g.rebuild
    assert(g.equiv?(fffa, fffb))
  end
end
