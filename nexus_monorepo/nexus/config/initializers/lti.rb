LTI_RESOURCE_HANDLERS = []

Dir[Rails.root.join('config', 'lti', 'resource_handlers', '*.json')].each do |rh|
  rh = File.read(rh)
  begin
    rh = JSON.parse(rh).with_indifferent_access
    rh.delete('$schema') if rh['$schema']
    LTI_RESOURCE_HANDLERS << rh
  rescue StandardError
    next
  end
end

LTI_DISABLE_DEVISE_NON_ADMIN_LOGIN = true

LTI_VALID_LMS_ORIGIN_HOSTS = [
  '192.168.1.81'
].freeze

LTI_TEACHER_ALLOW_COURSE_DELETE = true
LTI_TEACHER_MANAGE_ONLY_CURRENT_COURSE = false
LTI_TEACHER_MANAGE_ONLY_CURRENT_ASSIGNMENT = false

LTI_CIPHER_SECRET = '8cb13f93bf4b9bd12846d08c8814755d35fea3ff491bf08a0bbf381fe9a80892703ee58b072c18acc376d72b0d42ad392e42c63309e46e3aff63b450c396520d'.freeze

LTI_RH_ALL_CAPS = LtiUtils::RHHelper.all_caps!.freeze

LtiTool.clean_up!
LtiRegistration.clean_up!
