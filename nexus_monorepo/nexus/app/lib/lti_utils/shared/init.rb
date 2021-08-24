module LtiUtils
  class Init
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
    end
  end
end
