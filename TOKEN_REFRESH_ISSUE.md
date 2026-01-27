# Token Refresh Issue - Root Cause Analysis

## Problem Summary

The app requires re-authentication every ~60 minutes despite implementing proactive token refresh.

## Root Cause

**MSAL's token cache is not persisting across sessions.**

### Why This Happens

1. **MSAL manages refresh tokens internally** - We cannot access them directly
2. **MSAL stores tokens in macOS Keychain** - Using a keychain group tied to the bundle ID
3. **Something is preventing MSAL cache persistence** - Likely one of:
   - Keychain access group misconfiguration
   - Bundle ID changes between builds
   - App Sandboxing restrictions
   - MSAL cache getting cleared on app restart

### Evidence

- Proactive refresh attempts fail silently
- MSAL account cache is empty (`accounts.count == 0`)
- User must re-authenticate instead of silent token refresh working

## Current Implementation Status

### ✅ What Works
- Initial authentication (interactive flow)
- Token storage in our Keychain
- Token expiry tracking
- Proactive refresh triggers at correct time (45 minutes)

### ❌ What Doesn't Work
- MSAL cache persistence
- Silent token refresh (fails due to empty MSAL cache)
- Long-term sessions without re-authentication

## Potential Solutions

### Option 1: Configure MSAL Cache Location (Recommended)
Add explicit cache configuration when initializing MSAL:

```swift
let config = MSALPublicClientApplicationConfig(
    clientId: clientId,
    redirectUri: redirectUri,
    authority: authority
)

// Configure cache to use a specific keychain access group
config.cacheConfig.keychainSharingGroup = "com.nexer.KeepTheBudget"

msalApplication = try MSALPublicClientApplication(configuration: config)
```

**Issue**: Requires adding Keychain Sharing entitlement.

### Option 2: Manual Refresh Token Management
Store and manage refresh tokens manually (bypassing MSAL's cache).

**Issue**: MSAL doesn't expose refresh tokens in MSALResult.

### Option 3: Increase Token Lifetime
Request longer-lived tokens from Microsoft.

**Issue**: Requires Azure AD configuration changes, not always possible.

### Option 4: Accept Current Behavior
Users must re-authenticate periodically (every 60 minutes).

**Issue**: Poor user experience.

## Recommended Next Steps

1. **Add Keychain Sharing Entitlement**
   - Update `KeepTheBudget.entitlements`
   - Add keychain access group: `com.nexer.KeepTheBudget`

2. **Configure MSAL Cache**
   - Set explicit `keychainSharingGroup` in MSAL config
   - Ensure bundle ID matches keychain group

3. **Test Persistence**
   - Verify MSAL account cache persists across app restarts
   - Confirm silent token refresh works after restart

4. **Enhanced Logging**
   - Log MSAL cache location
   - Log keychain access group being used
   - Monitor MSAL account persistence

## Temporary Workaround

The current implementation provides:
- Proactive refresh attempts (reduces re-auth frequency)
- Better error messages
- Graceful re-authentication prompts

Users will need to re-authenticate approximately every 60 minutes until MSAL cache persistence is fixed.

## References

- [MSAL for iOS/macOS Documentation](https://github.com/AzureAD/microsoft-authentication-library-for-objc)
- [MSAL Cache Configuration](https://learn.microsoft.com/en-us/azure/active-directory/develop/msal-net-token-cache-serialization)
- [Keychain Sharing on macOS](https://developer.apple.com/documentation/security/keychain_services/keychain_items/sharing_access_to_keychain_items_among_a_collection_of_apps)
