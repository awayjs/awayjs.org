#!/usr/bin/env bash

exit 0

# See: https://gist.github.com/domenic/ec8b0fc8ab45f39403dd
# Script by Domenic

set -e # Exit with nonzero exit code if anything fails

SOURCE_BRANCH="master"
TARGET_BRANCH="gh-pages"

function doGenerate {
    echo "hexo generate"
    hexo generate
}

echo "Starting deploy..."
echo "pwd"
pwd
echo "ls -la"
ls -la

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Clone the existing gh-pages for this repo into out/
# Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deply)
echo "Creating deploy branch..."
git clone $REPO out
cd out
git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH
cd ..

# Clean out existing contents
echo "Clearing output..."
mv out/.git .git-gh-pages || true
rm -rf out || exit 0
mkdir out
mv .git-gh-pages out/.git
ls -la out

# Run our compile script
echo "Generating website..."
doGenerate
cp -r public/* out/
echo "ls -la out"
ls -la out

# Now let's go have some fun with the cloned repo
cd out
git config user.name "Travis CI"
git config user.email "palebluedot@gmail.com"

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
echo "Committing changes..."
git add -A
git diff-index --quiet HEAD || git commit -m "Deploy to GitHub Pages: ${SHA}"

# Get the deploy key by using Travis's stored variables to decrypt key.enc
echo "Decrypting github keys..."
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in ../deploy/deploy_key.enc -out deploy_key -d
chmod 600 deploy_key
eval `ssh-agent -s`
ssh-add deploy_key

# Now that we're all set up, we can push.
echo "Pushing build..."
git push $SSH_REPO $TARGET_BRANCH