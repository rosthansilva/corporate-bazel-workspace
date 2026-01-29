#!/bin/bash
set -e

# Inputs do CI
VERSION=$1
if [ -z "$VERSION" ]; then echo "Usage: ./ci_pipeline.sh <version>"; exit 1; fi

# Configurações do Ambiente
REGISTRY_ROOT="../../infrastructure/bcr-playground"
ARTIFACTORY_DIR="../../infrastructure/jfrog-storage"
ARTIFACTORY_URL="http://localhost:9000"
MODULE_NAME="corp_math"

echo "🚀 [CI] Iniciando Pipeline para $MODULE_NAME versão $VERSION..."

# 1. Preparar o pacote (Inject Version)
sed -i.bak "s/version = \".*\"/version = \"$VERSION\"/" MODULE.bazel
rm MODULE.bazel.bak

# 2. Criar Artefato (.tar.gz)
TAR_NAME="$MODULE_NAME-$VERSION.tar.gz"
tar -czf $TAR_NAME MODULE.bazel BUILD lib.cc lib.h
echo "📦 Artefato criado: $TAR_NAME"

# 3. Calcular Hash (Crucial para segurança)
SHA256=$(shasum -a 256 $TAR_NAME | awk '{print $1}')
echo "🔐 Hash: $SHA256"

# 4. Upload para JFrog (Mock)
mv $TAR_NAME "$ARTIFACTORY_DIR/"
echo "☁️  Upload para Artifactory concluído."

# 5. Registrar no BCR Playground
MOD_PATH="$REGISTRY_ROOT/modules/$MODULE_NAME/$VERSION"
mkdir -p "$MOD_PATH"

# 5.1 Copia MODULE.bazel (Metadata)
cp MODULE.bazel "$MOD_PATH/MODULE.bazel"

# 5.2 Cria source.json (Ponteiro)
cat > "$MOD_PATH/source.json" <<JSON
{
    "integrity": "sha256-$SHA256",
    "url": "$ARTIFACTORY_URL/$TAR_NAME",
    "strip_prefix": ""
}
JSON

# 5.3 Atualiza Lista de Versões (metadata.json)
META="$REGISTRY_ROOT/modules/$MODULE_NAME/metadata.json"
if [ ! -f "$META" ]; then
    echo "{\"versions\": [\"$VERSION\"], \"yanked_versions\": {}}" > "$META"
else
    # Hack simples para adicionar versão ao JSON sem usar 'jq'
    # Em produção use 'jq'
    sed -i.bak "s/\"versions\": \[/\"versions\": [\"$VERSION\", /" "$META"
    rm "$META.bak"
fi

echo "✅ [CI] Sucesso! Disponível no Playground BCR."