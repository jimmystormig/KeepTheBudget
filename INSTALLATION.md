# KeepTheBudget Installation Guide

## ✅ Installation Complete!

Your app has been installed to:
```
/Applications/KeepTheBudget.app
```

## 🚀 Auto-Start on Login (Recommended)

To make KeepTheBudget start automatically when you log in to macOS:

### Method 1: System Settings (Easiest - Recommended)

1. **Open System Settings**
   - Click the Apple menu () → **System Settings**

2. **Go to Login Items**
   - Click **General** in the sidebar
   - Click **Login Items**

3. **Add KeepTheBudget**
   - Click the **+** button under "Open at Login"
   - Navigate to **Applications**
   - Select **KeepTheBudget.app**
   - Click **Add**

4. **Done!**
   - KeepTheBudget will now start automatically when you log in
   - You can disable it anytime by selecting it and clicking the **−** button

### Method 2: Finder (Alternative)

1. **Open Finder**
2. Go to **Applications**
3. Find **KeepTheBudget.app**
4. **Right-click** → **Options** → **Open at Login**

## 📱 Using the App

### Menu Bar Icon

The app runs in your menu bar (top-right corner):
- **Clock icon** = Normal (within goals)
- **Red warning icon** = Over your daily or weekly goals

### Menu Bar Display

Shows your time in format: `Xh Ym / Xh Ym`
- **First number** = Today's scheduled time
- **Second number** = This week's scheduled time

Example: `6h 30m / 32h 15m`
- 6 hours 30 minutes today
- 32 hours 15 minutes this week

### Click the Icon

Opens a popover menu showing:
- **Daily Summary** with progress bar
- **Weekly Summary** with progress bar
- **Last updated** timestamp
- Quick actions:
  - **Refresh Now** - Manual refresh
  - **Preferences** - Change settings
  - **Quit** - Close the app

### Settings/Preferences

Click the icon → **Preferences** to access:

#### Goals Tab
- Set your **daily goal** (default: 8 hours)
- Set your **weekly goal** (default: 40 hours)
- Configure **update interval** (default: 10 minutes)

#### Calendar Tab
- **Change Calendar** - Switch which calendar to track

#### Account Tab
- View your signed-in account
- **Sign Out** - Remove authentication (will need to sign in again)

#### About Tab
- App version and information

## 🔄 Updates

The app automatically:
- ✅ Refreshes every 10 minutes (configurable)
- ✅ Updates the menu bar display
- ✅ Shows warnings when you exceed goals
- ✅ Counts all-day events as 8 hours
- ✅ Only tracks YOUR calendar events (not invites from others)

## 🆕 Updating the App

To update KeepTheBudget to a newer version:

### Step 1: Build the new version
```bash
cd KeepTheBudget
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Release clean build
```

### Step 2: Quit the running app
```bash
pkill KeepTheBudget
```

Or manually:
- Click the menu bar icon → **Quit KeepTheBudget**

### Step 3: Replace the app
```bash
# Remove old version
rm -rf /Applications/KeepTheBudget.app

# Copy new version
cp -R ~/Library/Developer/Xcode/DerivedData/KeepTheBudget-*/Build/Products/Release/KeepTheBudget.app /Applications/
```

### Step 4: Launch the updated app
```bash
open /Applications/KeepTheBudget.app
```

**Note:** Your preferences, authentication, and selected calendar will be preserved during the update.

## 🛠️ Troubleshooting

### App Not in Menu Bar
- The app runs as a menu bar app only (no Dock icon)
- Look for the clock icon in the top-right menu bar
- If you don't see it, quit and relaunch from Applications

### Authentication Issues
1. Click the menu bar icon → **Preferences** → **Account**
2. Click **Sign Out**
3. Quit the app
4. Relaunch from Applications
5. Sign in again

### Calendar Not Updating
1. Click the menu bar icon → **Refresh Now**
2. Check your internet connection
3. Verify you're signed in (Preferences → Account)

### Time Shows "0h 0m"
- Make sure you selected the correct calendar
- Verify the calendar has events where YOU are the organizer
- Events organized by others (meeting invites) are not counted

### Wrong Calendar
1. Click icon → **Preferences** → **Calendar**
2. Click **Change Calendar**
3. Select the correct calendar
4. Click **Continue**

## 🗑️ Uninstalling

To remove KeepTheBudget:

1. **Quit the app**
   - Click icon → **Quit KeepTheBudget**

2. **Remove from Login Items** (if added)
   - System Settings → General → Login Items
   - Select KeepTheBudget → Click **−** button

3. **Delete the app**
   ```bash
   # Move to Trash
   mv /Applications/KeepTheBudget.app ~/.Trash/
   ```

4. **Remove preferences** (optional)
   ```bash
   # Remove stored preferences
   defaults delete com.keepthebudget.KeepTheBudget

   # Remove keychain items (will prompt for password)
   # Open Keychain Access app and search for "office365" to delete tokens
   ```

## 📍 File Locations

### Application
```
/Applications/KeepTheBudget.app
```

### Source Code
```
(your local clone directory)
```

### Preferences
Stored in macOS UserDefaults:
```
~/Library/Preferences/com.keepthebudget.KeepTheBudget.plist
```

### Tokens (Secure)
Stored in macOS Keychain:
- Access token: `office365_access_token`
- Refresh token: `office365_refresh_token`

## 🆘 Support

For issues or questions:
- Check the [README.md](README.md) for detailed documentation
- Review [BUGFIX_THREAD_SAFETY.md](BUGFIX_THREAD_SAFETY.md) and [BUGFIX_MSAL_AUTH.md](BUGFIX_MSAL_AUTH.md) for known issues
- Check Xcode console output if running in development mode

## ✨ Tips

### Quick Access
- **⌘ + Click** the menu bar icon while holding Command to force refresh

### Goal Warnings
- The icon turns **red** when you exceed your daily OR weekly goals
- This helps you stay aware of your scheduling

### All-Day Events
- All-day events automatically count as **8 hours**
- This is configurable in a future version

### Event Filtering
- Only events where **you are the organizer** are counted
- Meeting invites from others are automatically excluded
- This ensures you only track time you scheduled yourself

### Calendar Selection
- You can track any of your Office 365 calendars
- Switch calendars anytime in Preferences
- Perfect for tracking specific projects or work calendars

---

**Congratulations!** 🎉

KeepTheBudget is now installed and ready to help you track your scheduled time from Office 365 Calendar!

**Version**: 1.0.0
**Last Updated**: January 2026
