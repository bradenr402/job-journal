# WebAuthn configuration for passkey authentication
# See: https://github.com/cedarcode/webauthn-ruby

WebAuthn.configure do |config|
  # This value needs to match `window.location.origin` evaluated by
  # the User Agent during registration and authentication ceremonies.
  config.origin = ENV.fetch("WEBAUTHN_ORIGIN") { "http://localhost:3000" }

  # Relying Party name for display purposes
  config.rp_name = "JobJournal"

  # Optionally configure a custom Relying Party ID
  # If not provided, defaults to the domain of the origin
  # config.rp_id = ENV.fetch("WEBAUTHN_RP_ID", nil)

  # Optionally configure credential options timeout (in milliseconds)
  # This hint specifies how long the browser should wait for any
  # interaction with the user.
  # config.credential_options_timeout = 120_000

  # Optionally configure the allowed algorithms
  # Default: ["ES256", "PS256", "RS256"]
  # config.algorithms = ["ES256", "PS256", "RS256"]
end
