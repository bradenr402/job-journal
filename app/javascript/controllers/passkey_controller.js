import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="passkey"
export default class extends Controller {
  static targets = ["status"]

  connect() {
    this.checkSupport()
  }

  checkSupport() {
    if (!window.PublicKeyCredential) {
      this.showError("Your browser doesn't support passkeys. Please use a modern browser (Chrome 109+, Safari 16+, Firefox 122+).")
    }
  }

  async register(event) {
    event.preventDefault()
    
    if (!window.PublicKeyCredential) {
      this.showError("Passkey support not available in your browser.")
      return
    }

    this.showStatus("Initiating passkey registration...")

    try {
      // Step 1: Get challenge from passkeys-rails API
      const challengeResponse = await fetch('/passkeys/challenge', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          username: this.currentUserEmail,
          authenticatable_class: 'User'
        })
      })

      if (!challengeResponse.ok) {
        const errorData = await challengeResponse.json()
        throw new Error(errorData.error || 'Failed to get challenge from server')
      }

      const challengeData = await challengeResponse.json()
      
      // Step 2: Create credential
      this.showStatus("Please authenticate with your device...")
      
      const credential = await navigator.credentials.create({
        publicKey: this.prepareCredentialCreationOptions(challengeData)
      })

      if (!credential) {
        throw new Error('No credential was created')
      }

      // Step 3: Register the credential with the server
      this.showStatus("Saving your passkey...")
      
      const registerResponse = await fetch('/passkeys/register', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          username: this.currentUserEmail,
          authenticatable_class: 'User',
          credential: this.encodeCredential(credential)
        })
      })

      if (!registerResponse.ok) {
        const errorData = await registerResponse.json()
        throw new Error(errorData.error || 'Failed to register passkey')
      }

      this.showSuccess("Passkey registered successfully! Redirecting...")
      
      // Redirect to security page after short delay
      setTimeout(() => {
        window.location.href = '/security'
      }, 1500)

    } catch (error) {
      console.error('Passkey registration error:', error)
      
      if (error.name === 'NotAllowedError') {
        this.showError('Passkey registration was cancelled.')
      } else if (error.name === 'InvalidStateError') {
        this.showError('This passkey is already registered.')
      } else {
        this.showError(error.message || 'Failed to register passkey. Please try again.')
      }
    }
  }

  prepareCredentialCreationOptions(challengeData) {
    // Convert base64url encoded strings to ArrayBuffers
    return {
      challenge: this.base64urlToBuffer(challengeData.challenge),
      rp: challengeData.rp,
      user: {
        id: this.base64urlToBuffer(challengeData.user.id),
        name: challengeData.user.name,
        displayName: challengeData.user.displayName
      },
      pubKeyCredParams: challengeData.pubKeyCredParams,
      timeout: challengeData.timeout,
      authenticatorSelection: challengeData.authenticatorSelection,
      attestation: challengeData.attestation
    }
  }

  encodeCredential(credential) {
    return {
      id: credential.id,
      rawId: this.bufferToBase64url(credential.rawId),
      type: credential.type,
      response: {
        clientDataJSON: this.bufferToBase64url(credential.response.clientDataJSON),
        attestationObject: this.bufferToBase64url(credential.response.attestationObject)
      }
    }
  }

  // Helper methods for base64url encoding/decoding
  base64urlToBuffer(base64url) {
    const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/')
    const padding = '='.repeat((4 - (base64.length % 4)) % 4)
    const binary = atob(base64 + padding)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i)
    }
    return bytes.buffer
  }

  bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ''
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
  }

  showStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = 'text-sm text-muted text-center mt-4'
    }
  }

  showSuccess(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = 'text-sm text-primary-600 dark:text-primary-500 text-center mt-4'
    }
  }

  showError(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = 'text-sm text-red-600 dark:text-red-400 text-center mt-4 p-3 bg-red-50 dark:bg-red-900/20 rounded'
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  get currentUserEmail() {
    // This should be set by the view
    return this.element.dataset.userEmail || 'user@example.com'
  }
}
