# Authentication & Token Refresh - Current Status

## Issue Summary

Users must re-authenticate approximately every **60 minutes** despite implementing automatic token refresh.

## Root Cause Identified

**MSAL (Microsoft Authentication Library) token cache is not persisting properly.**

### Why This Happens

1. **MSAL manages refresh tokens internally** - We cannot access or store them manually
2. **MSAL stores its cache in macOS Keychain** - But something prevents proper persistence
3. **When app restarts or MSAL cache is cleared** - Silent token refresh fails because there's no account in the cache

### Technical Details

- MSAL's `acquireTokenSilent()` requires an account from its cache
- If cache is empty (`accounts.count == 0`), silent refresh is impossible
- User must complete interactive authentication again
- After ~60 minutes, tokens expire and the cycle repeats

## What We've Tried

### ✅ Implemented
1. **Proactive Token Refresh** - Attempts to refresh tokens at 45 minutes (before expiration)
2. **Enhanced Logging** - Detailed logs showing MSAL cache status
3. **Token Expiry Tracking** - Moved to Keychain (more secure)
4. **Multiple Refresh Attempts** - With 10-minute data refresh cycles
5. **MSAL Cache Diagnostics** - Logs account count and cache state

### ❌ Attempted But Blocked
1. **Keychain Sharing Configuration** - Requires code signing/provisioning profile (not available for debug builds)
2. **Manual Refresh Token Management** - MSAL doesn't expose refresh tokens in API responses
3. **Custom Cache Location** - MSAL controls cache location

## Current Implementation

The app now includes:

### Aggressive Proactive Refresh
- Checks every 10 minutes during data refresh
- Triggers refresh when < 45 minutes remain (75% through token lifetime)
- Multiple opportunities to refresh before expiration

### Detailed Logging
Every refresh cycle logs:
```
🔐 Checking token status before data refresh...
🔄 Proactive token refresh check
   📊 Current token status: X minutes remaining
   📋 MSAL cache has X account(s)
```

### Graceful Error Handling
- Clear error messages when re-authentication needed
- One-click "Sign In Again" button
- No data loss during re-authentication

## Monitoring Token Refresh

To watch what's happening in real-time, run:

```bash
cd /Users/jimmy/Src/Nexer/KeepTheBudget
./watch-tokens.sh
```

This shows all token-related activity including:
- When proactive refresh checks occur
- MSAL account cache status
- Success/failure of refresh attempts
- Time until token expiration

## Expected Behavior

### Best Case Scenario
If MSAL cache persists properly:
- Initial authentication
- Tokens refresh automatically every ~45 minutes
- App runs indefinitely without re-authentication

### Current Reality
MSAL cache doesn't persist:
- Initial authentication
- Tokens expire after ~60 minutes
- User sees "Session expired" dialog
- User must sign in again
- Cycle repeats

## Why This Is Hard to Fix

1. **MSAL Design** - Refresh tokens are intentionally hidden for security
2. **macOS Sandboxing** - Restricts keychain access and cache persistence
3. **Code Signing** - Advanced keychain features require proper signing (not available for debug builds)
4. **MSAL is a Black Box** - We can't control its internal cache management

## Possible Long-Term Solutions

### Option 1: Production Code Signing
- Create Apple Developer account
- Enable proper code signing
- Use keychain-access-groups entitlement
- Configure MSAL to use shared keychain group

**Pros**: Should fix MSAL cache persistence
**Cons**: Requires Apple Developer Program membership ($99/year)

### Option 2: Use Different Auth Library
- Switch from MSAL to a library that exposes refresh tokens
- Manually manage refresh token storage and refresh logic

**Pros**: Full control over token lifecycle
**Cons**: Major refactoring, potential security issues if not done correctly

### Option 3: Accept Current Behavior
- Users re-authenticate every ~60 minutes
- Document this as a known limitation

**Pros**: No code changes needed
**Cons**: Poor user experience

## Recommendation

For now, **live with the current behavior** while monitoring to see if MSAL cache persistence improves. The enhanced logging will help diagnose if/when MSAL cache works properly.

If you need a production version that works indefinitely, pursue **Option 1** (proper code signing with keychain sharing).

## User Experience Impact

**Current**: Users must re-authenticate approximately once per hour while using the app.

**Workaround**: Keep the app running continuously. The 10-minute refresh cycles will keep fetching data, but authentication will expire after ~60 minutes of runtime.

## Files Created

1. `TOKEN_REFRESH_ISSUE.md` - Detailed root cause analysis
2. `AUTHENTICATION_STATUS.md` - This file (current status and recommendations)
3. `watch-tokens.sh` - Real-time monitoring script

## Next Steps

1. **Sign in and test** - See if the enhanced logging provides new insights
2. **Monitor for 1-2 hours** - Watch when/how authentication expires
3. **Check MSAL cache persistence** - See if account count stays > 0 across app restarts
4. **Decide on long-term solution** - Based on how critical this issue is for your workflow
