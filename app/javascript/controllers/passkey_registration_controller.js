import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="passkey-registration"
export default class extends Controller {
  static targets = ["name", "form", "submit", "error"]
  static values = {
    challengeUrl: String,
    createUrl: String
  }

  async register(event) {
    event.preventDefault()
    
    const passkeyName = this.nameTarget.value.trim()
    
    if (!passkeyName) {
      this.showError("Please enter a name for your passkey")
      return
    }

    // Check if WebAuthn is supported
    if (!window.PublicKeyCredential) {
      this.showError("Your browser doesn't support passkeys. Please use a modern browser.")
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
        throw new Error("Failed to get challenge from server")
      }

      const options = await challengeResponse.json()
      
      // Convert base64url strings to ArrayBuffers
      options.challenge = this.base64urlToBuffer(options.challenge)
      options.user.id = this.base64urlToBuffer(options.user.id)
      
      if (options.excludeCredentials) {
        options.excludeCredentials = options.excludeCredentials.map(cred => ({
          ...cred,
          id: this.base64urlToBuffer(cred.id)
        }))
      }

      // Step 2: Create credential with WebAuthn API
      const credential = await navigator.credentials.create({ publicKey: options })

      if (!credential) {
        throw new Error("Failed to create passkey")
      }

      // Step 3: Send credential to server
      const createResponse = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({
          id: this.bufferToBase64url(credential.rawId),
          rawId: this.bufferToBase64url(credential.rawId),
          type: credential.type,
          passkey_name: passkeyName,
          response: {
            clientDataJSON: this.bufferToBase64url(credential.response.clientDataJSON),
            attestationObject: this.bufferToBase64url(credential.response.attestationObject),
            transports: credential.response.getTransports ? credential.response.getTransports() : []
          }
        })
      })

      if (createResponse.ok) {
        // Turbo Stream will handle the update
        this.nameTarget.value = ""
      } else {
        const error = await createResponse.text()
        throw new Error(error || "Failed to register passkey")
      }
    } catch (error) {
      console.error("Passkey registration error:", error)
      
      if (error.name === "NotAllowedError") {
        this.showError("Passkey registration was cancelled")
      } else if (error.name === "InvalidStateError") {
        this.showError("This passkey is already registered")
      } else {
        this.showError(error.message || "Failed to register passkey")
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
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = loading
      this.submitTarget.textContent = loading ? "Creating..." : "Create Passkey"
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
