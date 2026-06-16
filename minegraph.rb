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

class Pattern; end

class Var < Pattern
  attr_accessor :name

  def initialize(name)
    @name = name
  end
end

class App < Pattern
  attr_accessor :f
  attr_accessor :children

  def initialize(f, children)
    @f = f
    @children = children
  end
end

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

  # Returns an id
  def instantiate(pattern, substitution)
    if pattern.is_a?(Var)
      result = substitution[pattern.name]
      raise "Could not match #{pattern.name}" if result == nil
      return result
    end
    raise unless pattern.is_a?(App)
    add_node(ENode.new(pattern.f, pattern.children.map { instantiate(it, substitution) }))
  end

  # Returns a list of nodes that are in the eclass `id`
  def nodes_in_class(id)
    hash_cons.select do |node, node_id|
      id == node_id
    end.keys
  end

  # Match `pattern` over the eclass `id` given the constraints `substitution`
  # Returns a list of substitutions
  def ematch_rec(pattern, id, substitution)
    raise "bug" if !substitution.is_a?(Hash)
    if pattern.is_a?(Var)
      substitution_id = substitution[pattern.name]
      # These two cases could be collapsed but why allocate a new substitution
      # if we don't have to?
      if substitution_id == nil
        [{pattern.name => id, **substitution}]
      elsif substitution_id == id
        [substitution]
      else
        []
      end
    else
      results = []
      nodes_in_class(id).filter do |node|
        # Filter for plausibly-matching nodes/patterns (by name/arity)
        node.f == pattern.f && node.children.length == pattern.children.length
      end.each do |node|
        todo = [substitution]
        pattern.children.zip(node.children) do |child_pattern, child_id|
          new_todo = []
          todo.each do |todo_substitution|
            new_todo.concat(ematch_rec(child_pattern, child_id, todo_substitution))
          end
          todo = new_todo
        end
        results.concat(todo)
      end
      results
    end
  end

  def ematch(pattern, id) = ematch_rec(pattern, id, {})

  def rewrite(rewrites)
    all_ids = Set[*hash_cons.values]
    all_matches = []
    rewrites.each do |left, right|
      all_ids.each do |id|
        substitutions = ematch(left, id)
        all_matches << [right, id, substitutions]
      end
    end
    all_matches.each do |right, id, substitutions|
      substitutions.each do |substitution|
        new_id = instantiate(right, substitution)
        union(id, new_id)
      end
    end
  end

  def saturate(rewrites)
    rebuild
    loop do
      len_parent = union_find.parent.length
      len_hash_cons = hash_cons.length
      rewrite(rewrites)
      rebuild
      if union_find.parent.length == len_parent && hash_cons.length == len_hash_cons
        break
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

  def test_instantiate_var_returns_value
    g = EGraph.new
    pattern = Var.new(:a)
    substitution = {a: 123}
    assert_equal(g.instantiate(pattern, substitution), 123)
  end

  def test_instantiate_app
    g = EGraph.new
    a = g.add_node(ENode.new(:a))
    b = g.add_node(ENode.new(:b))
    pattern = App.new(:f, [Var.new(:a), Var.new(:b)])
    substitution = {a: a, b: b}
    assert_equal(g.instantiate(pattern, substitution), 2)
  end

  def test_commutativity
    g = EGraph.new
    a = g.add_node(ENode.new(:a))
    b = g.add_node(ENode.new(:b))
    ab = g.add_node(ENode.new(:add, [a, b]))
    ba = g.add_node(ENode.new(:add, [b, a]))
    g.saturate([
      [App.new(:add, [Var.new(:x), Var.new(:y)]),
       App.new(:add, [Var.new(:y), Var.new(:x)])],
    ])
    assert(g.equiv?(ab, ba))
  end

  def test_commutativity_seven
    eg = EGraph.new
    a = eg.add_node(ENode.new(:a))
    b = eg.add_node(ENode.new(:b))
    c = eg.add_node(ENode.new(:c))
    d = eg.add_node(ENode.new(:d))
    e = eg.add_node(ENode.new(:e))
    f = eg.add_node(ENode.new(:f))
    g = eg.add_node(ENode.new(:g))

    # (a + (b + (c + (d + (e + (f + g)))))
    result = eg.add_node(ENode.new(:add, [f, g]))
    result = eg.add_node(ENode.new(:add, [e, result]))
    result = eg.add_node(ENode.new(:add, [d, result]))
    result = eg.add_node(ENode.new(:add, [c, result]))
    result = eg.add_node(ENode.new(:add, [b, result]))
    result = eg.add_node(ENode.new(:add, [a, result]))

    # (g + (f + (e + (d + (c + (b + a)))))
    flipped = eg.add_node(ENode.new(:add, [b, a]))
    flipped = eg.add_node(ENode.new(:add, [c, flipped]))
    flipped = eg.add_node(ENode.new(:add, [d, flipped]))
    flipped = eg.add_node(ENode.new(:add, [e, flipped]))
    flipped = eg.add_node(ENode.new(:add, [f, flipped]))
    flipped = eg.add_node(ENode.new(:add, [g, flipped]))

    eg.saturate([
      # (a + b) -> (b + a)
      [App.new(:add, [Var.new(:x), Var.new(:y)]),
       App.new(:add, [Var.new(:y), Var.new(:x)])],
      # (a + (b + c)) -> ((a + b) + c)
      [App.new(:add, [Var.new(:x), App.new(:add, [Var.new(:y), Var.new(:z)])]),
        App.new(:add, [App.new(:add, [Var.new(:x), Var.new(:y)]), Var.new(:z)])],
      # Not necessary but faster
      # # ((a + b) + c) -> (a + (b + c))
      # [App.new(:add, [App.new(:add, [Var.new(:x), Var.new(:y)]), Var.new(:z)]),
      #   App.new(:add, [Var.new(:x), App.new(:add, [Var.new(:y), Var.new(:z)])])],
    ])
    assert(eg.equiv?(result, flipped))
  end
end
