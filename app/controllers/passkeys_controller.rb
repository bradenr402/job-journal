class PasskeysController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:challenge_create, :challenge_authenticate]
  
  # Show form to create a new passkey
  def new
    @passkey = Passkey.new
  end

  # Generate challenge for creating a new passkey
  def challenge_create
    # Store options in session for verification later
    options = WebAuthn::Credential.options_for_create(
      user: {
        id: WebAuthn.generate_user_id,
        name: Current.user.email_address,
        display_name: Current.user.name || Current.user.email_address
      },
      exclude: Current.user.passkeys.pluck(:identifier),
      authenticator_selection: {
        user_verification: "preferred",
        resident_key: "preferred"
      }
    )

    session[:webauthn_registration_challenge] = options.challenge

    render json: options
  end

  # Verify and create the passkey
  def create
    webauthn_credential = WebAuthn::Credential.from_create(params)
    
    begin
      webauthn_credential.verify(session[:webauthn_registration_challenge])
      
      passkey = Current.user.passkeys.build(
        identifier: Base64.urlsafe_encode64(webauthn_credential.raw_id, padding: false),
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        name: params[:passkey_name] || "Passkey",
        transports: webauthn_credential.response.transports
      )

      if passkey.save
        session.delete(:webauthn_registration_challenge)
        
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend("passkeys_list", partial: "passkeys/item", locals: { passkey: passkey }),
              turbo_stream.update("passkey_form", partial: "passkeys/form"),
              turbo_stream.append("flash", partial: "layouts/flash_message", locals: { 
                type: :success, 
                message: "Passkey '#{passkey.name}' created successfully" 
              })
            ]
          end
          format.json { render json: { success: true, passkey: passkey }, status: :created }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.append("flash", partial: "layouts/flash_message", locals: { 
              type: :error, 
              message: "Failed to create passkey: #{passkey.errors.full_messages.join(', ')}" 
            }), status: :unprocessable_entity
          end
          format.json { render json: { errors: passkey.errors }, status: :unprocessable_entity }
        end
      end
    rescue WebAuthn::Error => e
      session.delete(:webauthn_registration_challenge)
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("flash", partial: "layouts/flash_message", locals: { 
            type: :error, 
            message: "Passkey verification failed: #{e.message}" 
          }), status: :unprocessable_entity
        end
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  # Delete a passkey
  def destroy
    passkey = Current.user.passkeys.find(params[:id])
    passkey_name = passkey.name
    
    if passkey.destroy
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove("passkey_#{passkey.id}"),
            turbo_stream.append("flash", partial: "layouts/flash_message", locals: { 
              type: :success, 
              message: "Passkey '#{passkey_name}' deleted successfully" 
            })
          ]
        end
        format.html { redirect_to security_path, notice: "Passkey '#{passkey_name}' deleted successfully" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("flash", partial: "layouts/flash_message", locals: { 
            type: :error, 
            message: "Failed to delete passkey" 
          }), status: :unprocessable_entity
        end
        format.html { redirect_to security_path, error: "Failed to delete passkey" }
      end
    end
  end

  # Generate challenge for authentication
  def challenge_authenticate
    options = WebAuthn::Credential.options_for_get(
      allow: User.joins(:passkeys).pluck(:"passkeys.identifier").map { |id| Base64.urlsafe_decode64(id) }
    )

    session[:webauthn_authentication_challenge] = options.challenge

    render json: options
  end

  # Verify passkey and sign in
  def authenticate
    webauthn_credential = WebAuthn::Credential.from_get(params)
    credential_id = Base64.urlsafe_encode64(webauthn_credential.raw_id, padding: false)
    
    passkey = Passkey.find_by(identifier: credential_id)

    if passkey
      begin
        webauthn_credential.verify(
          session[:webauthn_authentication_challenge],
          public_key: passkey.public_key,
          sign_count: passkey.sign_count
        )

        # Update sign count and last used timestamp
        passkey.update!(
          sign_count: webauthn_credential.sign_count,
          last_used_at: Time.current
        )

        # Sign in the user
        start_new_session_for passkey.user
        session.delete(:webauthn_authentication_challenge)

        respond_to do |format|
          format.json { render json: { success: true, redirect_url: after_authentication_url } }
          format.html { redirect_to after_authentication_url, notice: "Signed in successfully with passkey" }
        end
      rescue WebAuthn::SignCountVerificationError => e
        # Sign count verification failed - possible cloned authenticator
        Rails.logger.warn("Sign count verification failed for passkey #{passkey.id}: #{e.message}")
        
        respond_to do |format|
          format.json { render json: { error: "Security error: passkey verification failed" }, status: :unauthorized }
          format.html { redirect_to new_session_path, error: "Security error: passkey verification failed" }
        end
      rescue WebAuthn::Error => e
        session.delete(:webauthn_authentication_challenge)
        
        respond_to do |format|
          format.json { render json: { error: "Authentication failed: #{e.message}" }, status: :unauthorized }
          format.html { redirect_to new_session_path, error: "Authentication failed" }
        end
      end
    else
      session.delete(:webauthn_authentication_challenge)
      
      respond_to do |format|
        format.json { render json: { error: "Passkey not found" }, status: :not_found }
        format.html { redirect_to new_session_path, error: "Passkey not found" }
      end
    end
  end
end
