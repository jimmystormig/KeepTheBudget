# Bug Fix: MSAL Authentication Error -50000

## Issue

When clicking "Sign In", the authentication failed with:

```
Authentication failed: The operation couldn't be completed.
(MSALErrorDomain error -50000.)
```

## Root Cause

MSAL error code **-50000** typically indicates one of these issues:
1. Invalid or unauthorized client ID
2. Missing or incorrect redirect URI configuration
3. Webview configuration problems

## Fixes Applied

### 1. Updated Client ID

**Problem**: The original client ID (`d3590ed6-52b3-4102-aeff-aad2292ab01c` - Microsoft Office) was not suitable for third-party applications.

**Solution**: Changed to Microsoft Graph Explorer client ID which is designed for development and testing:

**File**: `KeepTheBudget/Utilities/Constants.swift`
```swift
// OLD
static let clientId = "d3590ed6-52b3-4102-aeff-aad2292ab01c" // Microsoft Office

// NEW
static let clientId = "de8bc8b5-d9f9-48b1-a8ad-b748da725064" // Microsoft Graph Explorer
```

### 2. Configured Redirect URI

**Problem**: No redirect URI was specified, causing authentication callbacks to fail.

**Solution**: Set explicit redirect URI for macOS:

**File**: `KeepTheBudget/Services/AuthManager.swift`
```swift
private func setupMSAL() {
    do {
        // Set redirect URI to MSAL default format for macOS
        let redirectUri = "msauth.com.nexer.KeepTheBudget://auth"
        let config = MSALPublicClientApplicationConfig(
            clientId: GraphConstants.clientId,
            redirectUri: redirectUri,
            authority: authority
        )
        msalApplication = try MSALPublicClientApplication(configuration: config)
    } catch {
        print("Failed to initialize MSAL: \(error)")
    }
}
```

### 3. Registered URL Scheme in Info.plist

**Problem**: macOS didn't know how to handle the redirect callback from authentication.

**Solution**: Added URL scheme registration:

**File**: `KeepTheBudget/App/Info.plist`
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.com.nexer.KeepTheBudget</string>
        </array>
    </dict>
</array>
```

### 4. Set Webview Type

**Problem**: Default webview type might not work on all macOS versions.

**Solution**: Explicitly set webview type:

**File**: `KeepTheBudget/Services/AuthManager.swift`
```swift
func startInteractiveAuth(parentWindow: NSWindow? = nil) async throws -> String {
    // On macOS, MSAL uses the system browser
    let webviewParameters = MSALWebviewParameters()
    webviewParameters.webviewType = .default
    let interactiveParameters = MSALInteractiveTokenParameters(
        scopes: GraphConstants.scopes,
        webviewParameters: webviewParameters
    )
    // ... rest of implementation
}
```

## How MSAL Authentication Works Now

1. **User clicks "Sign In"**
2. **App requests authentication** via `authManager.startInteractiveAuth()`
3. **MSAL opens system browser** with Microsoft login page
4. **User authenticates** in the browser
5. **Browser redirects to** `msauth.com.nexer.KeepTheBudget://auth` with auth code
6. **macOS launches app** via registered URL scheme
7. **MSAL receives callback** and exchanges code for tokens
8. **Tokens saved to Keychain** for future use

## Testing

After the fix:

✅ **Build Status**: BUILD SUCCEEDED
✅ **Client ID**: Using Microsoft Graph Explorer (development/testing)
✅ **Redirect URI**: Properly configured
✅ **URL Scheme**: Registered in Info.plist

## Next Steps

When you run the app now:

1. **Click "Sign In"**
2. **System browser should open** with Microsoft login page
3. **Sign in with your Office 365 account**
4. **Grant permissions** when prompted
5. **Browser will redirect** and app should receive the token
6. **App proceeds to calendar selection**

## Important Notes for Production

### Client ID for Production Use

The current client ID (`de8bc8b5-d9f9-48b1-a8ad-b748da725064`) is the **Microsoft Graph Explorer** client, which is designed for development and testing.

**For production deployment**, you should:

1. **Register your own app** at https://portal.azure.com
2. **Configure it as a Public Client** (not requiring client secret)
3. **Add the redirect URI**: `msauth.com.nexer.KeepTheBudget://auth`
4. **Grant API permissions**:
   - `Calendars.Read`
   - `User.Read`
   - `offline_access`
5. **Update Constants.swift** with your client ID

### How to Register Your App

1. Go to https://portal.azure.com
2. Navigate to **Azure Active Directory** → **App registrations**
3. Click **New registration**
4. Set:
   - **Name**: KeepTheBudget
   - **Supported account types**: Accounts in any organizational directory and personal Microsoft accounts
   - **Redirect URI**: Public client/native → `msauth.com.nexer.KeepTheBudget://auth`
5. Click **Register**
6. Go to **Authentication** tab
   - Enable "Public client flows"
   - Add redirect URI if not already added
7. Go to **API permissions** tab
   - Add **Microsoft Graph** → **Delegated permissions**:
     - `Calendars.Read`
     - `User.Read`
     - `offline_access`
8. Copy the **Application (client) ID**
9. Update `Constants.swift`:
   ```swift
   static let clientId = "your-client-id-here"
   ```

## Alternative Client IDs

If the Microsoft Graph Explorer client doesn't work, you can try:

### Azure CLI Client ID
```swift
static let clientId = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
```

### Visual Studio Code Client ID
```swift
static let clientId = "aebc6443-996d-45c2-90f0-388ff96faa56"
```

These are all public client IDs from Microsoft that support interactive authentication.

## Troubleshooting

### If authentication still fails:

1. **Check internet connection** - MSAL needs to reach Microsoft servers
2. **Try different browser** - Set it as default if needed
3. **Clear keychain** - Delete any old tokens from Keychain Access
4. **Check console logs** - Look for MSAL error messages
5. **Verify redirect URI matches** between code and Info.plist

### Common MSAL Errors

- **-50000**: Configuration issue (client ID, redirect URI)
- **-50001**: User cancelled authentication
- **-50002**: Network error
- **-42001**: User cancelled interactive flow
- **-42003**: Invalid redirect URI

## Files Modified

- `KeepTheBudget/Utilities/Constants.swift` - Updated client ID
- `KeepTheBudget/Services/AuthManager.swift` - Added redirect URI and webview config
- `KeepTheBudget/App/Info.plist` - Registered URL scheme
- `KeepTheBudget/Views/DeviceCodeView.swift` - Added AppKit import (for NSApp)

## Build Status

✅ **CLEAN BUILD SUCCEEDED**

The project compiles without errors and is ready to test.

---

**Fixed**: January 20, 2026
**Status**: Ready for Testing
**Next**: Run the app and try Sign In again!
