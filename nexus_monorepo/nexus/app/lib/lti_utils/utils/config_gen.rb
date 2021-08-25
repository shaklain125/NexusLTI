module LtiUtils
  class ConfigGenerator
    def initialize
      @attributes = Set.new
    end

    def configure(&block)
      block.call(self) if block_given?
    end

    def respond_to_missing?(method_name, include_private = false)
      method_name.to_s.end_with?("=") || super
    end

    def method_missing(method_name, *args, &block)
      raise unless method_name.to_s.end_with?("=")

      getter = method_name.to_s.slice(0...-1).to_sym
      inst_var = "@#{getter}".to_sym
      define_singleton_method(getter) { instance_variable_get(inst_var) }
      define_singleton_method("#{getter}!".to_sym) { to_ostruct(instance_variable_get(inst_var)) }
      @attributes.add(getter)

      setter = method_name
      define_singleton_method(setter) { |v| instance_variable_set(inst_var, v) }
      send(setter, args[0])
    rescue StandardError
      super(method_name, *args, &block) if method_name.to_s.end_with?("=")
    end

    def to_ostruct(obj)
      HashHelper.to_ostruct(obj)
    end

    def as_ostruct
      to_ostruct(as_json)
    end

    def as_json
      @attributes.each_with_object({}) { |a, h| h[a] = send(a) }
    end

    private :to_ostruct
  end
end
