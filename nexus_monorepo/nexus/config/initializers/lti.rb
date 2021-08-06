LTI_RESOURCE_HANDLERS = []

Dir[Rails.root.join('config', 'lti', 'resource_handlers', '*.yml')].each do |yml|
  config = YAML.load(File.read(yml)).with_indifferent_access
  LTI_RESOURCE_HANDLERS << config
end

LTI_DISABLE_DEVISE_NON_ADMIN_LOGIN = true

LTI_ENABLE_COOKIE_TOKEN_WHEN_HTTP = false

LTI_VALID_LMS_ORIGIN_HOSTS = [
  '192.168.1.81'
].freeze
