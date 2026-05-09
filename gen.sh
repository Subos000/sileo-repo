#!/bin/bash
# ============================================================
# Sileo Repo - Packages & Release 自动生成脚本
# ============================================================

set -e

REPO_NAME="鸭鸭"
REPO_LABEL=" Sileo Repo"
REPO_DESC="duck's Sileo jailbreak repository"
REPO_CODENAME="ios"
REPO_ARCH="iphoneos-arm64 iphoneos-arm64e"
REPO_COMPONENTS="main"
SUITE="stable"

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  Sileo Repo Generator"
echo "=========================================="

# 收集所有 .deb 到 debs/ 根目录
echo "[*] 收集 debs 目录中的软件包..."
find debs -name "*.deb" | while read deb; do
    dirpart=$(dirname "$deb")
    if [ "$dirpart" != "debs" ]; then
        cp "$deb" debs/
        echo "    + $(basename "$deb")"
    fi
done

# 清空旧文件
> Packages
DEB_COUNT=0

# 处理 debs/ 根目录下的 .deb
for deb in debs/*.deb; do
    [ -f "$deb" ] || continue
    echo "    - 处理: $(basename "$deb")"
    dpkg-deb -f "$deb" >> Packages
    echo "Filename: ./debs/$(basename "$deb")" >> Packages
    STAT_OUT=$(stat -c%s "$deb")
    echo "Size: $STAT_OUT" >> Packages
    echo "MD5sum: $(md5sum "$deb" | cut -d' ' -f1)" >> Packages
    echo "SHA1: $(sha1sum "$deb" | cut -d' ' -f1)" >> Packages
    echo "SHA256: $(sha256sum "$deb" | cut -d' ' -f1)" >> Packages
    echo "SHA512: $(sha512sum "$deb" 2>/dev/null | cut -d' ' -f1)" >> Packages
    echo "" >> Packages
    DEB_COUNT=$((DEB_COUNT + 1))
done

if [ "$DEB_COUNT" -eq 0 ]; then
    echo "[!] 未找到任何 .deb 文件"
    exit 0
fi

echo "[*] 共处理 $DEB_COUNT 个软件包"

# ---- 压缩 ----
echo "[*] 正在压缩..."
gzip -9fc Packages > Packages.gz

S_PKG=$(stat -c%s Packages)
S_GZ=$(stat -c%s Packages.gz)

M_PKG=$(md5sum Packages | cut -d' ' -f1)
M_GZ=$(md5sum Packages.gz | cut -d' ' -f1)
S1_PKG=$(sha1sum Packages | cut -d' ' -f1)
S1_GZ=$(sha1sum Packages.gz | cut -d' ' -f1)
S2_PKG=$(sha256sum Packages | cut -d' ' -f1)
S2_GZ=$(sha256sum Packages.gz | cut -d' ' -f1)

# ---- 生成 Release ----
echo "[*] 生成 Release..."
DATE=$(date -R)
cat > Release << EOF
Origin: $REPO_NAME
Label: $REPO_LABEL
Suite: $SUITE
Codename: $REPO_CODENAME
Architectures: $REPO_ARCH
Components: $REPO_COMPONENTS
Description: $REPO_DESC
Date: $DATE
MD5Sum:
 $M_PKG $S_PKG Packages
 $M_GZ $S_GZ Packages.gz
SHA1:
 $S1_PKG $S_PKG Packages
 $S1_GZ $S_GZ Packages.gz
SHA256:
 $S2_PKG $S_PKG Packages
 $S2_GZ $S_GZ Packages.gz
EOF

echo "=========================================="
echo "  完成！$DEB_COUNT 个软件包"
echo "=========================================="
ls -lh Packages Packages.gz Release
