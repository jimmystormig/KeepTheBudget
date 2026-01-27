#!/bin/bash
# Watch KeepTheBudget token refresh activity in real-time

echo "🔍 Monitoring KeepTheBudget token refresh activity..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log stream --predicate 'process == "KeepTheBudget"' --level info --style compact 2>/dev/null | \
  grep --line-buffered -E "(Proactive|Token|expires|refresh|MSAL|account|CRITICAL|Session)"
