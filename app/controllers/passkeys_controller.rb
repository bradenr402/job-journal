class PasskeysController < ApplicationController
  def new
    @agent = PasskeysRails::Agent.find_or_create_by(authenticatable: Current.user) do |agent|
      agent.username = Current.user.email_address
    end
  end

  def register
    # Create agent if it doesn't exist
    agent = PasskeysRails::Agent.find_or_create_by(authenticatable: Current.user) do |a|
      a.username = Current.user.email_address
    end
    
    redirect_to security_path, notice: "Passkey registered successfully"
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
