class ParserNode

  module Types
    SOMETHING = 0
    MANY      = 1
    TAG       = 2
    TEXT      = 3
    REGEX     = 4
    SCOPE     = 5
    VARIABLE  = 6
  end

  attr_reader :type, :value, :child, :next

  def initialize(type, value, child, next)
    @type = type
    @value = value
    @child = child
    @next = next
  end

end

class ParserResult
  attr_reader :valid, :partial, :tail

  def initialize args
    @valid = false
    @partial = false
    @tail = nil

    args.each do |k, v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
  end

  def valid?
    @valid
  end

  def partial?
    @partial
  end
end

class ScopeChain

  def initialize
    @scope_chain = Array.new
  end

  def clone
    @scope_chain.map { |scope| scope.clone }
  end

  def <<(scope)
    # scope is a Hash
    @scope_chain << scope.clone
  end

  def last
    # returns the last scope
    @scope_chain.last.clone
  end

  def [](key)
    # TODO: chaining
    @scope_chain.last[key]
  end

  def []=(key, value)
    @scope_chain.last[key] = value
  end

  def merge! scope
    # merges scope with the last scope
    @scope_chain.last.merge! scope.clone
  end
end

def parse(parser_node, html_node, scope_chain)
  scope_chain = scope_chain.clone
  if parser_node.nil?
    if html_node.nil?
      result = ParserResult.new valid: true
    else
      result = ParserResult.new valid: false, partial: true, tail: html_node
    end
    new_scope_chain = scope_chain
  else
    case parser_node.type
    when ParserNode::Types::SOMETHING:
      result, new_scope_chain = parse(parser_node.child, html_node, scope_chain)
      unless result.valid?
        # it's not valid, keep trying
        result, new_scope_chain = parse(parser_node, html_node.next, scope_chain)
      end
    when ParserNode::Types::MANY:
      # creates a brand new scope chain per iteration
      per_iteration_scope_chain = scope_chain.clone << Hash.new # scope_chain is cloned so it can be used later
      result, new_scope_chain = parse(parser_node.child, html_node, per_iteration_scope_chain)
      unless result.valid?
        if result.partial?
          # partial results, keep iterating
          result, new_scope_chain = parse(parser_node, result.tail, scope_chain)
        end
      end
    when ParserNode::Types::TAG:
      if parser_node.tag == html_node.tag
        result, new_scope_chain = parse(parser_node.child, html_node.child, scope_chain)
        if result.valid?
          temp_result, temp_scope_chain = parse(parser_node.next, html_node.next, new_scope_chain)
          result.merge temp_result
          new_scope_chain.merge! temp_scope_chain.last
        end
      else
        result = ParserResult.new valid: false
        new_scope_chain = scope_chain
      end
    when ParserNode::Types::TEXT:
      if html_node.text? and parser_node.text == html_node.text
        result = ParserResult.new valid: true, ans: html_node.text
      else
        result = ParserResult.new valid: false
      end
      new_scope_chain = scope_chain
    when ParserNode::Types::REGEX:
      if html_node.text? and parser_node.regexp =~ html_node.text
        result = ParserResult.new valid: true, ans: html_node.text
      else
        result = ParserResult.new valid: false
      end
      new_scope_chain = scope_chain
    when ParserNode::Types::SCOPE:
      scope_chain << Hash.new
      result, new_scope_chain = parse(parser_node.child, html_node, scope_chain)
    when ParserNode::Types::VARIABLE:
      result, new_scope_chain = parse(parser_node.child, html_node, scope_chain)
      if result.valid?
        new_scope_chain[parser_node.variable_name] = result.ans
      end
    end
  end

  return result, new_scope_chain
end