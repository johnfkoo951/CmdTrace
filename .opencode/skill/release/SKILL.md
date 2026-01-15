# CmdTrace Release Skill

Use this skill when preparing a CmdTrace release. This checklist ensures all version references, documentation, and assets are properly updated.

## Trigger Phrases
- `/release`
- "release CmdTrace"
- "prepare release"
- "version bump"
- "배포 준비"

## Release Checklist

### 1. Version Files (MUST update all three)

| File | Location | Current Pattern |
|------|----------|-----------------|
| `build-app.sh` | Line 7 | `VERSION="X.X.X"` |
| `CLAUDE.md` | Line ~181 | `Current: vX.X.X` |
| `website/index.html` | Multiple locations | `vX.X.X` and download links |

**Commands to check current versions:**
```bash
grep -n "VERSION=" build-app.sh
grep -n "Current:" CLAUDE.md
grep "version" website/index.html | head -5
```

### 2. Documentation Updates

- [ ] **README.md**: Update features, search operators, keyboard shortcuts
- [ ] **CLAUDE.md**: Update version number
- [ ] **website/index.html**: Update version badge and download links

### 3. Build Process

```bash
# Build app
./build-app.sh

# Create DMG
./build-dmg.sh

# Install to Applications (for testing)
cp -r "./build/CmdTrace.app" /Applications/
```

### 4. Git Operations

```bash
# Stage all changes
git add -A

# Commit with version
git commit -m "chore: release vX.X.X"

# Create tag
git tag vX.X.X

# Push
git push origin main
git push origin vX.X.X
```

### 5. GitHub Release

```bash
# Create release with DMG
gh release create vX.X.X ./build/*.dmg \
  --title "CmdTrace vX.X.X" \
  --notes "Release notes here"
```

## Version Numbering (SemVer)

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Breaking changes | MAJOR | 2.0.0 → 3.0.0 |
| New features | MINOR | 2.2.0 → 2.3.0 |
| Bug fixes | PATCH | 2.3.0 → 2.3.1 |

## Post-Release Verification

- [ ] App launches correctly from /Applications
- [ ] Version shows correctly in app
- [ ] New features work as expected
- [ ] Download links work on website
- [ ] GitHub release page shows correct assets
