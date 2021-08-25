module LtiUtils
  class Setup
    class << self
      def clean_up!
        LtiTool.clean_up!
        LtiRegistration.clean_up!
      rescue StandardError => e
        puts(e.message)
      end

      def lti_paths!(router)
        RHHelper.init_lti_paths!(router)
      end

      def new_config
        ConfigGenerator.new
      end

      def config
        LTI_CONFIG || new_config
      end

      def configure(ctx, &block)
        ctx.const_set('LTI_CONFIG', new_config)
        config.configure { |c| block.call(c, self) }
      end

      private :new_config
    end
  end
end
