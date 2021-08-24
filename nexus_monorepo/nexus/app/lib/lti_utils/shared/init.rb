module LtiUtils::Init
  class << self
    def clean_up!
      LtiTool.clean_up!
      LtiRegistration.clean_up!
    rescue StandardError => e
      puts(e.message)
    end
  end
end
