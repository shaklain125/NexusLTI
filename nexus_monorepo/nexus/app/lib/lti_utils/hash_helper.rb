module LtiUtils
  class HashHelper
    class << self
      def snake_case(value)
        value = value.to_h
        value = value.map { |k, v| [k.to_s.underscore.to_sym, v.is_a?(Hash) ? snake_case(v) : v] }
        value.to_h
      end

      def snake_case_arr(value)
        value.map do |v|
          if v.is_a?(Hash)
            snake_case(v)
          else
            v.is_a?(Array) ? snake_case_arr(v) : v
          end
        end
      end

      def snake_case_sym_obj(value)
        case value
        when Array
          snake_case_arr(value)
        when Hash
          snake_case_symbolize(value)
        else
          value
        end
      end

      def snake_case_symbolize(value)
        snake_case(value).symbolize_keys
      end

      def stringify(value)
        value = value.to_h
        value = value.map { |k, v| [k.to_s, v.is_a?(Hash) ? stringify(v) : v] }
        value.to_h
      end
    end
  end
end
