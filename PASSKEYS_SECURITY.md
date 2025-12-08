# Passkeys Security Documentation

This document outlines the security implementation for WebAuthn passkey support in JobJournal.

## Security Architecture

### WebAuthn Protocol
JobJournal implements the WebAuthn standard for passkey authentication using the `webauthn` Ruby gem (v3.1.0).

### Challenge-Response Flow

#### Registration
1. Client requests challenge via `POST /passkeys/challenge_create`
2. Server generates cryptographic challenge using `WebAuthn::Credential.options_for_create`
3. Challenge stored in session for verification
4. Client uses WebAuthn API to create credential with device authenticator
5. Client sends credential back via `POST /passkeys`
6. Server verifies challenge matches and stores public key

#### Authentication
1. Client requests challenge via `POST /passkeys/challenge_authenticate`
2. Server generates challenge using `WebAuthn::Credential.options_for_get`
3. Challenge stored in session for verification
4. Client uses WebAuthn API to sign challenge with passkey
5. Client sends signed response via `POST /passkeys/authenticate`
6. Server verifies signature and sign count, creates session

## Security Features

### 1. One-Time Challenges
- Each challenge is cryptographically random and used only once
- Stored in Rails session (encrypted cookie)
- Deleted immediately after verification
- Prevents replay attacks

### 2. Origin Verification
- Configured via `WEBAUTHN_ORIGIN` environment variable
- Must match `window.location.origin` in browser
- Prevents phishing attacks from malicious sites
- Example: `https://job-journal.fly.dev`

### 3. Sign Count Tracking
- Each passkey maintains a sign count
- Increments with each authentication
- Server verifies count always increases
- Detects cloned authenticators

### 4. User Scoping
- All passkey operations scoped to `Current.user`
- No cross-user access possible
- Enforced at controller and model level

### 5. Public Key Storage
- Only public keys stored in database
- Private keys remain on user's device
- Even database compromise cannot reveal private keys

### 6. Transport Information
- Tracks authenticator transports (USB, NFC, internal, etc.)
- Improves UX by suggesting appropriate authenticator
- No security impact

## Configuration

### Required Environment Variables

```bash
# Production
WEBAUTHN_ORIGIN=https://your-domain.com

# Development (default)
WEBAUTHN_ORIGIN=http://localhost:3000
```

### WebAuthn Configuration
See `config/initializers/webauthn.rb`:
- RP Name: "JobJournal"
- User Verification: "preferred" (not required)
- Resident Key: "preferred" (not required)
- Timeout: 120 seconds (default)

## Security Best Practices

### For Developers
1. Never log passkey credentials or challenges
2. Always scope queries to `Current.user`
3. Validate all WebAuthn responses
4. Keep webauthn gem updated
5. Use HTTPS in production

### For Users
1. Register passkeys on devices you control
2. Use biometrics or device PIN when available
3. Register multiple passkeys for backup
4. Delete passkeys for lost/stolen devices

## Threat Model

### Protected Against
- ✅ Phishing attacks (origin verification)
- ✅ Replay attacks (one-time challenges)
- ✅ Cloned authenticators (sign count verification)
- ✅ Man-in-the-middle (HTTPS + origin verification)
- ✅ Database compromise (public key cryptography)
- ✅ Cross-user access (proper scoping)

### Out of Scope
- ❌ Physical device theft (user must protect device)
- ❌ Compromised user device (OS-level security)
- ❌ Browser vulnerabilities (vendor responsibility)

## Compliance

### Standards
- W3C WebAuthn Level 2
- FIDO2 Alliance specifications
- Rails 8 security best practices

### Privacy
- No biometric data stored on server
- Only public keys and metadata stored
- User can delete all passkeys at any time

## Incident Response

### If Sign Count Verification Fails
1. Log warning (already implemented)
2. Reject authentication
3. User should re-register passkey
4. Investigate possible cloning

### If Challenge Verification Fails
1. Clear challenge from session
2. Return error to client
3. User can retry registration/authentication

### If Database Compromised
1. Public keys exposed but useless without private keys
2. Rotate session secrets
3. Users should re-register passkeys as precaution
4. No immediate security risk

## Testing

### Test Coverage
- 11 model tests (validations, associations, scoping)
- 5 controller tests (CRUD, authorization, challenges)
- Fixtures for integration testing
- All tests passing

### Security Testing
- SQL injection: Protected by ActiveRecord
- XSS: Protected by Rails auto-escaping
- CSRF: Token verification in place
- Authorization: Scoping enforced throughout

## References

- [WebAuthn Specification](https://www.w3.org/TR/webauthn/)
- [webauthn-ruby Documentation](https://github.com/cedarcode/webauthn-ruby)
- [FIDO Alliance](https://fidoalliance.org/)
