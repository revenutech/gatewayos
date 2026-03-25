---
title: "Runbook: Git Signed Commits"
iso_ref: "A.5.28 (Collection of evidence), A.8.4 (Access to source code)"
---

# Git Signed Commits Setup

> **GAP-09:** Git commits are not currently signed.
> This runbook documents the procedure to enable GPG/SSH signed commits for non-repudiation.

## Setup GPG Signing

### 1. Generate GPG Key (per developer)
```bash
gpg --full-generate-key
# Select: RSA and RSA, 4096 bits, no expiry (or 2 years)
# Enter name and email matching GitHub account
```

### 2. Configure Git
```bash
# Get key ID
GPG_KEY=$(gpg --list-secret-keys --keyid-format=long | grep sec | awk '{print $2}' | cut -d'/' -f2)

# Configure Git to sign commits
git config --global user.signingkey $GPG_KEY
git config --global commit.gpgsign true
git config --global tag.gpgsign true
```

### 3. Add to GitHub
```bash
# Export public key
gpg --armor --export $GPG_KEY

# Paste in GitHub → Settings → SSH and GPG keys → New GPG key
```

### 4. Configure GitHub Branch Protection
In repository Settings → Branches → main:
- [x] Require signed commits

## Alternative: SSH Signing (Simpler)
```bash
# Use existing SSH key
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519
git config --global commit.gpgsign true
```

## Verify
```bash
# Check a signed commit
git log --show-signature -1

# Verify all recent commits are signed
git log --format='%H %G? %GK %an' -10
# G = Good signature, N = No signature
```

## CI Enforcement
Add to `.github/workflows/compliance.yml`:
```yaml
- name: "A.5.28: Verify commit signatures"
  run: |
    UNSIGNED=$(git log --format='%H %G?' origin/main..HEAD | grep -c ' N$' || true)
    if [ "$UNSIGNED" -gt 0 ]; then
      echo "WARNING: $UNSIGNED unsigned commits found"
    fi
```

## Status
- **Current:** Unsigned commits (GAP-09)
- **Target:** All commits GPG/SSH signed
- **Due:** 2026-Q2
