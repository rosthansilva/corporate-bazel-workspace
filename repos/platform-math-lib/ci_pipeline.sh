#!/bin/bash
set -e

# CI Inputs
VERSION=$1
if [ -z "$VERSION" ]; then echo "Usage: ./ci_pipeline.sh <version>"; exit 1; fi

# Environment Configuration
REGISTRY_ROOT="../../infrastructure/bcr-playground"
ARTIFACTORY_DIR="../../infrastructure/jfrog-storage"
ARTIFACTORY_URL="http://localhost:9000"
MODULE_NAME="corp_math"

echo "🚀 [CI] Starting Pipeline for $MODULE_NAME version $VERSION..."

# 1. Prepare package (Inject Version)
sed -i.bak "s/version = \".*\"/version = \"$VERSION\"/" MODULE.bazel
rm MODULE.bazel.bak

# 2. Create Artifact (.tar.gz)
TAR_NAME="$MODULE_NAME-$VERSION.tar.gz"
tar -czf $TAR_NAME MODULE.bazel BUILD lib.cc lib.h
echo "📦 Artifact created: $TAR_NAME"

# 3. Calculate Hash (Crucial for security)
SHA256=$(shasum -a 256 $TAR_NAME | awk '{print $1}')
echo "🔐 Hash: $SHA256"

# 4. Upload to JFrog (Mock)
mv $TAR_NAME "$ARTIFACTORY_DIR/"
echo "☁️  Upload to Artifactory completed."

# 5. Register in BCR Playground
MOD_PATH="$REGISTRY_ROOT/modules/$MODULE_NAME/$VERSION"
mkdir -p "$MOD_PATH"

# 5.1 Copy MODULE.bazel (Metadata)
cp MODULE.bazel "$MOD_PATH/MODULE.bazel"

# 5.2 Create source.json (Pointer)
cat > "$MOD_PATH/source.json" <<JSON
{
    "integrity": "sha256-$SHA256",
    "url": "$ARTIFACTORY_URL/$TAR_NAME",
    "strip_prefix": ""
}
JSON

# 5.3 Update Version List (metadata.json)
META="$REGISTRY_ROOT/modules/$MODULE_NAME/metadata.json"
if [ ! -f "$META" ]; then
    echo "{\"versions\": [\"$VERSION\"], \"yanked_versions\": {}}" > "$META"
else
    # Simple hack to add version to JSON without using 'jq'
    # In production, use 'jq' for better reliability
    sed -i.bak "s/\"versions\": \[/\"versions\": [\"$VERSION\", /" "$META"
    rm "$META.bak"
fi

echo "✅ [CI] Success! Available in BCR Playground."