module Parsers
  class << self
    def registry
      constants(false)
        .without(:Base)
        .map(&:to_s)
        .sort
    end

    def all
      registry.map { |name| const_get(name) }
    end

    def source_names
      all.map { it::SOURCE_NAME }
    end

    def hosts
      all.flat_map { it::ALLOWED_HOSTS }.uniq
    end

    def for_host(host)
      normalized_host = host.to_s.downcase
      all.find { it::ALLOWED_HOSTS.include? normalized_host }
    end
  end
end
