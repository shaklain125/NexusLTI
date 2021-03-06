module LtiUtils
  class ErrorHandlers
    class << self
      def lti_error(ex)
        "Reason: #{case ex.error
                   when :invalid_signature
                     'The OAuth Signature was Invalid'
                   when :invalid_nonce
                     'The nonce has already been used'
                   when :request_to_old
                     'The request is to old'
                   when :invalid_origin
                     'Invalid Origin'
                   when :invalid_lti_role_access
                     'Invalid LTI role access'
                   when :invalid_aid
                     'Assignment has not been set'
                   when :assigment_not_started
                     'Assigment has not started'
                   when :invalid_page_access
                     'Page access disabled'
                   when :course_not_found
                     'The current course cannot be found in Nexus'
                   else
                     if ex.error.to_s.starts_with?('MSG:')
                       ex.error.to_s[4..-1].strip
                     else
                       "Unknown Error: #{ex.error.to_s.underscore.titleize}"
                     end
                   end}"
      end

      def lti_reg_error(ex)
        "Reason: Unknown Error: #{ex.error.to_s.underscore.titleize}"
      end
    end
  end
end
