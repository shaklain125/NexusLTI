module LtiUtils
  class HashHelper
    class << self
      def snake_case(value)
        value = value.to_h
        value = value.map { |k, v| [k.to_s.underscore.to_sym, hash_type?(v) ? snake_case(v) : v] }
        value.to_h
      end

      def snake_case_arr(value)
        value.map do |v|
          if hash_type?(v)
            snake_case(v)
          else
            v.is_a?(Array) ? snake_case_arr(v) : v
          end
        end
      end

      def snake_case_sym_obj(value)
        value = value.to_h if hash_type?(value)
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
        value = value.map { |k, v| [k.to_s, hash_type?(v) ? stringify(v) : v] }
        value.to_h
      end

      def nested_hash_val(obj, key)
        if obj.respond_to?(:key?) && obj.key?(key)
          obj[key]
        elsif obj.respond_to?(:each)
          r = nil
          obj.find { |*a| r = nested_hash_val(a.last, key) }
          r
        end
      end

      def hash_type?(obj)
        obj.is_a?(Hash) || obj.class.ancestors.include?(Hash)
      end

      def to_ostruct(obj)
        obj = obj.to_h if hash_type?(obj)
        case obj
        when Hash
          obj = obj.map { |key, val| [key, to_ostruct(val)] }
          OpenStruct.new(obj.to_h)
        when Array
          obj = obj.map { |val| to_ostruct(val) }
          obj.to_a
        else
          obj
        end
      end

      def from_ostruct(obj)
        obj = obj.to_h if obj.is_a?(OpenStruct)
        obj = obj.to_h if hash_type?(obj)
        case obj
        when Hash
          obj = obj.map { |key, val| [key, val.is_a?(OpenStruct) ? from_ostruct(val) : val] }
          obj.to_h
        when Array
          obj = obj.map { |val| val.is_a?(OpenStruct) ? from_ostruct(val) : val }
          obj.to_a
        else
          obj
        end
      end
    end
  end
end
