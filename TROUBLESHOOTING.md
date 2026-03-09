# Troubleshooting Guide

## pixel-dashboard Build Failures

### Issue: "fnm: command not found"

**Error Message:**
```
/home/pi/Development/pixel-dashboard/build.sh: line 13: fnm: command not found
```

**Root Cause:**
The pixel-dashboard build script attempts to initialize the Fast Node Manager (fnm) for Node.js version management, but fnm is not installed or not in the PATH.

**Impact:**
When `deploy.sh` calls the sync-games script, it may trigger the pixel-dashboard build, which fails with the fnm error. This prevents games from being synced to the web dashboard.

**Solution:**

Option 1: Install fnm (Recommended)
```bash
curl -fsSL https://fnm.io/install | bash
```

Option 2: Ensure system Node.js is available
If you prefer not to use fnm, make sure Node.js and npm are available in your PATH:
```bash
node --version
npm --version
```

Option 3: Update pixel-dashboard to handle missing fnm gracefully
The pixel-dashboard `build.sh` can be updated to:
1. Check if fnm is available before trying to use it
2. Fall back to system Node.js if fnm is not found
3. Provide clear error messages if neither fnm nor system Node.js is available

(Note: This requires changes to the pixel-dashboard repository, which are outside the scope of this PR.)

**Verification:**
After installing fnm or ensuring system Node.js is available, test the deployment:
```bash
/home/pi/Development/pixel-dashboard/scripts/sync-games.sh
```

## Deployment Resilience

The game-a-day `deploy.sh` has been updated to handle pixel-dashboard sync failures gracefully:
- If sync fails, a warning is logged but the deployment continues
- Games are still exported and available locally even if the web dashboard sync fails
- This prevents pixel-dashboard issues from breaking the entire game deployment pipeline
