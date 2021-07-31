module LtiUtils
  class HashHelper
    def self.snake_case(value)
      value = value.to_h
      value = value.map { |k, v| [k.to_s.underscore.to_sym, v.is_a?(Hash) ? snake_case(v) : v] }
      value.to_h
    end

    def self.snake_case_symbolize(value)
      snake_case(value).symbolize_keys
    end
  end
end
