# Quick Deployment Guide

## Deploy an Update

```bash
# Quick one-liner (copy and paste)
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Debug build && \
killall KeepTheBudget 2>/dev/null; \
rm -rf /Applications/KeepTheBudget.app && \
cp -R ~/Library/Developer/Xcode/DerivedData/KeepTheBudget-*/Build/Products/Debug/KeepTheBudget.app /Applications/ && \
open /Applications/KeepTheBudget.app
```

## Step by Step

1. **Build the app:**
   ```bash
   xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Debug build
   ```

2. **Kill running instances:**
   ```bash
   killall KeepTheBudget 2>/dev/null
   ```

3. **Copy to Applications:**
   ```bash
   rm -rf /Applications/KeepTheBudget.app
   cp -R ~/Library/Developer/Xcode/DerivedData/KeepTheBudget-*/Build/Products/Debug/KeepTheBudget.app /Applications/
   ```

4. **Launch:**
   ```bash
   open /Applications/KeepTheBudget.app
   ```

## Important Notes

⚠️ **DO NOT manually re-sign the app** - this breaks entitlements and causes crashes

✅ **DO copy directly from Xcode build** - preserves proper code signing with entitlements

## After New Files Added

If you added new Swift files (models, views, etc.), regenerate the Xcode project first:

```bash
xcodegen generate
```

Then follow the deployment steps above.

## Verify Deployment

Check the app is running:
```bash
ps aux | grep "Applications/KeepTheBudget.app" | grep -v grep
```

You should see the clock icon in your menu bar (top-right corner).

## Troubleshooting

**App doesn't show in menu bar?**
- Test in Xcode first: `open KeepTheBudget.xcodeproj` then press ⌘R
- Check Console.app for errors

**App crashes after deployment?**
- Never happened if you followed the steps above
- If it does, you may have manually re-signed - rebuild and redeploy without re-signing

**Changes not showing up?**
- Make sure you built first: `xcodebuild ... build`
- Check you're copying from the correct DerivedData path
- Try a clean build: add `clean` before `build`
