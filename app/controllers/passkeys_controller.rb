class PasskeysController < ApplicationController
  skip_forgery_protection only: [:challenge, :register]
  
  def new
    # Page for creating a new passkey
  end

  def challenge
    # Create or find agent for current user
    agent = PasskeysRails::Agent.find_or_initialize_by(authenticatable: Current.user)
    
    if agent.new_record?
      agent.username = Current.user.email_address
      agent.webauthn_identifier = WebAuthn.generate_user_id
      agent.save!
    end

    # Generate WebAuthn challenge
    options = WebAuthn::Credential.options_for_create(
      user: { 
        id: agent.webauthn_identifier, 
        name: agent.username,
        display_name: Current.user.name || Current.user.email_address
      }
    )

    # Store challenge in session for later verification
    session[:passkey_challenge] = options.challenge
    session[:passkey_agent_id] = agent.id

    render json: options.as_json
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def register
    agent = PasskeysRails::Agent.find(session[:passkey_agent_id])
    challenge = session[:passkey_challenge]

    # Verify and store the credential
    webauthn_credential = WebAuthn::Credential.from_create(params[:credential])
    webauthn_credential.verify(challenge)

    # Store the passkey
    agent.passkeys.create!(
      identifier: webauthn_credential.id,
      public_key: webauthn_credential.public_key,
      sign_count: webauthn_credential.sign_count
    )

    agent.update!(registered_at: Time.current) unless agent.registered?

    # Clear session data
    session.delete(:passkey_challenge)
    session.delete(:passkey_agent_id)

    render json: { success: true }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    agent = PasskeysRails::Agent.find_by(authenticatable: Current.user)
    passkey = agent&.passkeys&.find_by(id: params[:id])
    
    if passkey&.destroy
      redirect_to security_path, notice: "Passkey deleted successfully"
    else
      redirect_to security_path, error: "Passkey not found"
    end
  end
end
