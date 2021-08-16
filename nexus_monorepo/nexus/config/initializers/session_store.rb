# Be sure to restart your server when you modify this file.

# Production HTTPS. Make sure comment out the development lines below to use HTTPS.
# For LTI session within Iframe
# Use this if Nexus is able to run with HTTPS.

LTI_HTTPS_SESSION = true
LTI_HTTP_SESSION = false
LTI_ENABLE_COOKIE_TOKEN_WHEN_HTTP = false

Rails.application.config.session_store :cookie_store,  {
  key: '_nexus_session',
  secure: true, # Nexus needs to run with HTTPS so set this to true. HTTP session will not work.
  same_site: :none
}

# Development HTTP. Make sure comment out the lines above to use HTTP.

# LTI_HTTPS_SESSION = false
# LTI_HTTP_SESSION = true
# LTI_ENABLE_COOKIE_TOKEN_WHEN_HTTP = true

# Rails.application.config.session_store :cookie_store, key: '_nexus_session'
