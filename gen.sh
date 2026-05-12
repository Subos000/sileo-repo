#!/bin/bash
# ============================================================
# Sileo Repo - Packages & Release 自动生成脚本 (增量版)
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
echo "  Sileo Repo Generator (增量)"
echo "=========================================="

# ---------- 收集所有 .deb 到 debs/ 根目录 ----------
echo "[*] 收集 debs 目录中的软件包..."
find debs -name "*.deb" | while read deb; do
    dirpart=$(dirname "$deb")
    if [ "$dirpart" != "debs" ]; then
        cp "$deb" debs/
        echo "    + $(basename "$deb")"
    fi
done

# ---------- 加载缓存（文件名 -> MD5）----------
declare -A CACHE_MAP
if [ -f .packages_cache ]; then
    while read -r fname fmd5; do
        [ -n "$fname" ] && CACHE_MAP["$fname"]="$fmd5"
    done < .packages_cache
fi

# ---------- 解析旧 Packages，建立映射（文件名 -> 完整段落）----------
declare -A PKG_MAP
if [ -f Packages ]; then
    echo "[*] 读取旧 Packages 索引..."
    pkg_content=""
    while IFS= read -r line || [ -n "$line" ]; do
        if [ -z "$line" ]; then
            # 空行：一个段落结束
            if [ -n "$pkg_content" ]; then
                # 提取 Filename 字段
                filename=$(echo "$pkg_content" | grep "^Filename: " | head -1 | sed 's/^Filename: *//')
                if [ -n "$filename" ]; then
                    PKG_MAP["$filename"]="$pkg_content"
                fi
                pkg_content=""
            fi
        else
            pkg_content+="$line"$'\n'
        fi
    done < Packages
    # 处理文件末尾可能没有空行的最后一段
    if [ -n "$pkg_content" ]; then
        filename=$(echo "$pkg_content" | grep "^Filename: " | head -1 | sed 's/^Filename: *//')
        if [ -n "$filename" ]; then
            PKG_MAP["$filename"]="$pkg_content"
        fi
    fi
fi

# ---------- 处理 debs/ 下的所有 .deb ----------
> Packages
declare -A NEW_CACHE
DEB_COUNT=0

for deb in debs/*.deb; do
    [ -f "$deb" ] || continue

    deb_filename="./debs/$(basename "$deb")"   # 与 Packages 中的 Filename 一致
    current_md5=$(md5sum "$deb" | cut -d' ' -f1)
    cached_md5="${CACHE_MAP[$deb_filename]}"

    # 判断是否可以复用旧段落
    if [ -n "$cached_md5" ] && [ "$cached_md5" == "$current_md5" ] && [ -n "${PKG_MAP[$deb_filename]}" ]; then
        echo "    - 复用: $(basename "$deb")"
        # 直接使用旧段落，并补充一个空行作为分隔
        printf '%s\n\n' "${PKG_MAP[$deb_filename]}" >> Packages
    else
        echo "    - 处理: $(basename "$deb")"
        dpkg-deb -f "$deb" >> Packages
        echo "Filename: $deb_filename" >> Packages
        echo "Size: $(stat -c%s "$deb")" >> Packages
        echo "MD5sum: $current_md5" >> Packages
        echo "SHA1: $(sha1sum "$deb" | cut -d' ' -f1)" >> Packages
        echo "SHA256: $(sha256sum "$deb" | cut -d' ' -f1)" >> Packages
        echo "SHA512: $(sha512sum "$deb" 2>/dev/null | cut -d' ' -f1)" >> Packages
        echo "" >> Packages
    fi

    # 记录到新缓存
    NEW_CACHE["$deb_filename"]="$current_md5"
    DEB_COUNT=$((DEB_COUNT + 1))
done

if [ "$DEB_COUNT" -eq 0 ]; then
    echo "[!] 未找到任何 .deb 文件"
    exit 0
fi

echo "[*] 共处理 $DEB_COUNT 个软件包"

# 更新缓存文件（按文件名排序，方便 diff 查看）
> .packages_cache
for key in "${!NEW_CACHE[@]}"; do
    echo "$key ${NEW_CACHE[$key]}"
done | sort >> .packages_cache

# ---------- 压缩 ----------
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

# ---------- 生成 Release ----------
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