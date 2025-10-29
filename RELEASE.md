# Release Process

This document describes how to create a new release of Xamrock CLI and update the Homebrew formula.

## Automated Release (Recommended)

The project uses GitHub Actions to automatically update the Homebrew formula when a new release is published.

### Creating a Release

1. **Ensure all changes are committed**:
   ```bash
   git add .
   git commit -m "Prepare for release 0.2.0"
   git push origin main
   ```

2. **Create and push the tag** (without 'v' prefix):
   ```bash
   git tag 0.2.0
   git push origin 0.2.0
   ```

3. **Create the GitHub release**:
   - Go to https://github.com/Xamrock/CLI/releases/new
   - Select the tag you just pushed (0.2.0)
   - Set release title (e.g., "Release 0.2.0")
   - Add release notes describing changes
   - Click "Publish release"

4. **Automatic Homebrew update**:
   - The GitHub Action will automatically:
     - Download the release tarball
     - Calculate the SHA256 hash
     - Update the Homebrew formula in `xamrock/homebrew-tap`
     - Push changes to the tap repository
   - Check the Actions tab to see the workflow progress
   - Users can then run `brew upgrade xamrock` to get the new version

### Required Setup (One-time)

For the automation to work, you need to configure a GitHub token:

1. **Create a Personal Access Token**:
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Name: "Homebrew Tap Updater"
   - Scopes: Select `repo` (full control of private repositories)
   - Click "Generate token"
   - **Copy the token immediately** (you won't see it again)

2. **Add token to CLI repository secrets**:
   - Go to https://github.com/xamrock/CLI/settings/secrets/actions
   - Click "New repository secret"
   - Name: `HOMEBREW_TAP_TOKEN`
   - Value: Paste the token you copied
   - Click "Add secret"

That's it! Future releases will automatically update the Homebrew formula.

## Manual Release (Fallback)

If you need to update the formula manually or the automation fails:

### 1. Create and Push the Release Tag

```bash
git tag 0.2.0
git push origin 0.2.0
```

### 2. Create the GitHub Release

Create the release via the web interface at https://github.com/Xamrock/CLI/releases/new

### 3. Download and Calculate SHA256

```bash
VERSION=0.2.0
curl -L -o xamrock.tar.gz "https://github.com/Xamrock/CLI/archive/refs/tags/$VERSION.tar.gz"
shasum -a 256 xamrock.tar.gz
```

### 4. Update the Homebrew Formula

```bash
cd ../homebrew-tap

# Edit Formula/xamrock.rb
# Update the url line with new version (without 'v' prefix)
# Update the sha256 line with calculated hash

git add Formula/xamrock.rb
git commit -m "Update xamrock formula to version $VERSION"
git push
```

### 5. Test the Update

```bash
brew update
brew upgrade xamrock
xamrock --help
```

## Version Numbering

- Use semantic versioning: `MAJOR.MINOR.PATCH`
- **Do NOT use 'v' prefix** in tags (use `0.2.0`, not `v0.2.0`)
- The workflow will handle both formats if accidentally used

## Quick Release Checklist (Automated)

- [ ] All changes committed and pushed
- [ ] Create and push git tag (e.g., `0.2.0` without 'v' prefix)
- [ ] Create GitHub release
- [ ] Verify GitHub Action completed successfully
- [ ] Test installation with `brew upgrade xamrock`

## Quick Release Checklist (Manual)

- [ ] All changes committed and pushed
- [ ] Create and push git tag (e.g., `0.2.0`)
- [ ] Create GitHub release
- [ ] Download release tarball
- [ ] Calculate SHA256 hash
- [ ] Update `homebrew-tap/Formula/xamrock.rb` with new version and SHA256
- [ ] Commit and push formula changes
- [ ] Test installation with `brew upgrade xamrock`

## Troubleshooting

### Workflow Fails with "Permission denied"

- Check that the `HOMEBREW_TAP_TOKEN` secret is set correctly in the CLI repository
- Verify the token has `repo` scope permissions
- Make sure the token hasn't expired

### Formula SHA256 Mismatch

- The workflow automatically calculates the correct hash
- If manual intervention is needed, download the exact tarball GitHub generates
- Use: `shasum -a 256 <tarball>` (not `sha256sum` on macOS)

### Workflow Doesn't Trigger

- Ensure the release is published (not just a draft)
- Check the Actions tab for any errors
- Verify the workflow file is in `.github/workflows/update-homebrew.yml`

### Formula Syntax Errors

Test your formula locally before pushing:

```bash
brew install --build-from-source Formula/xamrock.rb
```

### Build Failures

If the Homebrew build fails, check:
- Swift toolchain version requirements
- Dependencies are correctly specified
- Build commands work in a clean directory

### Users Report Issues

If users report installation issues:

1. Test the formula yourself:
   ```bash
   brew uninstall xamrock
   brew install --verbose --debug xamrock
   ```

2. Check the build logs for errors
3. Update the formula if needed
4. Notify users to `brew update && brew upgrade xamrock`
