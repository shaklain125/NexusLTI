load(Rails.root.join('db', 'seeds', "#{Rails.env.downcase}.rb"))

LtiTool.create!(uuid: 'key', shared_secret: 'secret', lti_version: 'LTI-1p0', tool_settings: 'none')
