class Array
  def deep_compact_blank!
    each do |v|
      v.deep_compact_blank! if v.respond_to?(:deep_compact_blank!)
    end.compact_blank!
  end
end

class Hash
  def deep_compact_blank!
    each do |k, v|
      v.deep_compact_blank! if v.respond_to?(:deep_compact_blank!)
    end.compact_blank!
  end
end

module Enumerable
  def deep_compact_blank
    deep_dup.deep_compact_blank!
  end

  def to_disjunctive_sentence
    to_sentence two_words_connector: " or ", last_word_connector: ", or "
  end
end
