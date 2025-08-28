#!/bin/bash
set -e

echo "🚀 Starting build process..."

# 1. Read the version from the single source of truth.
APP_VERSION=$(grep -oP "^VERSION = '\K[^']+" "src/marquee_monitor_setup.py")
echo "✅ Detected version: $APP_VERSION"

# 2. Update the .spec file IN-PLACE.
echo "📝 Updating spec file to version $APP_VERSION..."
sed -i "s/^Version: .*/Version: $APP_VERSION/" "src/marquee-utility.spec"

# 3. Create the source tarball from the 'src' directory.
echo "📦 Creating source archive..."
RPM_SOURCE_DIR="$HOME/rpmbuild/SOURCES"
mkdir -p "$RPM_SOURCE_DIR"
# --- THIS IS THE FIX ---
# Add the --transform flag to create the correct top-level directory inside the archive.
tar --exclude-vcs --transform="s|^.|marquee-utility-${APP_VERSION}|" -czvf "$RPM_SOURCE_DIR/marquee-utility-${APP_VERSION}.tar.gz" -C src .

# 4. Build the RPM.
echo "🔧 Building RPM package..."
rpmbuild -ba "src/marquee-utility.spec"
echo "✅ RPM build complete."

# 5. Find and copy the new RPM into your separate repo folder.
echo "🚚 Copying new RPM into local repo..."
REPO_DIR="$HOME/marquee-magic_repo"
REPO_PKG_DIR="$REPO_DIR/aarch64"
mkdir -p "$REPO_PKG_DIR"
find "$HOME/rpmbuild/RPMS/noarch/" -name "marquee-utility-${APP_VERSION}-*.rpm" -exec cp {} "$REPO_PKG_DIR/" \;
# --- ADD THIS LINE ---
cp "src/change-marquee-password" "$REPO_PKG_DIR/"
# --- ADD THIS LINE ---
cp "src/reset-marquee-wifi" "$REPO_PKG_DIR/"
echo "✅ RPM copied."

# 6. Update the repo metadata.
echo "🔄 Updating repository metadata..."
createrepo_c --update "$REPO_DIR"
echo "✅ Repository metadata updated."

# 7. Commit and push the repo.
echo "🌐 Committing and pushing to GitHub..."
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m "release: marquee-utility v${APP_VERSION}"
git -C "$REPO_DIR" push

echo "🎉 Process complete!"
