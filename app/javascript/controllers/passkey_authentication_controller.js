import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="passkey-authentication"
export default class extends Controller {
  static targets = ["button", "error"]
  static values = {
    challengeUrl: String,
    authenticateUrl: String
  }

  async authenticate(event) {
    event.preventDefault()

    // Check if WebAuthn is supported
    if (!window.PublicKeyCredential) {
      this.showError("Your browser doesn't support passkeys. Please use password sign in instead.")
      return
    }

    this.clearError()
    this.setLoading(true)

    try {
      // Step 1: Get challenge from server
      const challengeResponse = await fetch(this.challengeUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })

      if (!challengeResponse.ok) {
        throw new Error("Failed to get authentication challenge")
      }

      const options = await challengeResponse.json()
      
      // Convert base64url strings to ArrayBuffers
      options.challenge = this.base64urlToBuffer(options.challenge)
      
      if (options.allowCredentials) {
        options.allowCredentials = options.allowCredentials.map(cred => ({
          ...cred,
          id: this.base64urlToBuffer(cred.id)
        }))
      }

      // Step 2: Get credential with WebAuthn API
      const credential = await navigator.credentials.get({ publicKey: options })

      if (!credential) {
        throw new Error("No passkey selected")
      }

      // Step 3: Send credential to server for verification
      const authResponse = await fetch(this.authenticateUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          id: this.bufferToBase64url(credential.rawId),
          rawId: this.bufferToBase64url(credential.rawId),
          type: credential.type,
          response: {
            clientDataJSON: this.bufferToBase64url(credential.response.clientDataJSON),
            authenticatorData: this.bufferToBase64url(credential.response.authenticatorData),
            signature: this.bufferToBase64url(credential.response.signature),
            userHandle: credential.response.userHandle ? this.bufferToBase64url(credential.response.userHandle) : null
          }
        })
      })

      const result = await authResponse.json()

      if (authResponse.ok && result.success) {
        // Redirect to the specified URL
        window.location.href = result.redirect_url
      } else {
        throw new Error(result.error || "Authentication failed")
      }
    } catch (error) {
      console.error("Passkey authentication error:", error)
      
      if (error.name === "NotAllowedError") {
        this.showError("Authentication was cancelled")
      } else if (error.name === "InvalidStateError") {
        this.showError("No eligible passkeys found for this site")
      } else {
        this.showError(error.message || "Failed to authenticate with passkey")
      }
    } finally {
      this.setLoading(false)
    }
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    } else {
      alert(message)
    }
  }

  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ""
      this.errorTarget.classList.add("hidden")
    }
  }

  setLoading(loading) {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = loading
      const originalText = this.buttonTarget.dataset.originalText || "Sign in with Passkey"
      this.buttonTarget.dataset.originalText = originalText
      this.buttonTarget.textContent = loading ? "Authenticating..." : originalText
    }
  }

  // Helper methods for base64url encoding/decoding
  base64urlToBuffer(base64url) {
    const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/')
    const padding = '='.repeat((4 - (base64.length % 4)) % 4)
    const base64Padded = base64 + padding
    const binary = atob(base64Padded)
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
    const base64 = btoa(binary)
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
