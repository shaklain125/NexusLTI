LTI_CONFIG = YAML.load(File.read("#{Rails.root}/config/lti.yml"))[Rails.env].symbolize_keys

LTI_RESOURCE_HANDLERS = []

Dir[Rails.root.join('config', 'resource_handlers', '*.yml')].each do |yml|
  config = YAML.load(File.read(yml)).with_indifferent_access
  LTI_RESOURCE_HANDLERS << config
end
