# Quick Start Guide

Get started with KeepTheBudget in 3 simple steps!

## Step 1: Build the App

```bash
cd /Users/jimmy/Src/Nexer/KeepTheBudget
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Debug build
```

Or open in Xcode:
```bash
open KeepTheBudget.xcodeproj
```
Then press ⌘R to build and run.

## Step 2: Run the App

### From Xcode:
- Click the "Run" button (▶️) or press ⌘R

### From Command Line:
```bash
open ~/Library/Developer/Xcode/DerivedData/KeepTheBudget-*/Build/Products/Debug/KeepTheBudget.app
```

The app will appear in your menu bar (look for the clock icon in the top-right).

## Step 3: Sign In

1. Click the clock icon in the menu bar
2. Click "Sign In" in the window that appears
3. A browser window will open
4. Sign in with your Office 365 account
5. Grant the requested permissions
6. Select which calendar to track
7. Done! The app starts tracking immediately

## What You'll See

**Menu Bar:**
```
🕐 6h 30m / 32h 15m
```
- First number: Today's scheduled hours
- Second number: This week's scheduled hours

**When Over Goal:**
```
🔴 8h 45m / 42h 15m
```
- Red icon warns you're over your goals!

**Click the Icon:**
- See detailed breakdown
- View progress bars
- Access settings
- Refresh manually

## Default Settings

- **Daily Goal**: 8 hours
- **Weekly Goal**: 40 hours
- **Update Interval**: Every 10 minutes
- **All-Day Events**: Count as 8 hours

## Customize Settings

1. Click the menu bar icon
2. Click "Preferences"
3. Adjust goals and settings
4. Changes save automatically

## Tips

✅ **Only YOUR events count** - Meeting invites from others are excluded
✅ **Real-time tracking** - Updates every 10 minutes automatically
✅ **Visual warnings** - Red icon when you exceed goals
✅ **Secure** - Tokens stored in macOS Keychain

## Need Help?

See the full [README.md](README.md) for detailed documentation.

---

**That's it!** Your calendar time is now being tracked. 🎉
