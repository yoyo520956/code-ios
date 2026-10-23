#!/bin/bash
set -e

echo "🔧 Building Code iOS App..."

# 安装依赖
echo "📦 Installing dependencies..."
brew install xcodegen

# 生成 Xcode 项目
echo "🔨 Generating Xcode project..."
xcodegen generate

# 构建
echo "🏗️ Building project..."
xcodebuild build \
    -project Code.xcodeproj \
    -scheme Code \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee build.log

# 检查结果
if grep -q "BUILD SUCCEEDED" build.log; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed!"
    tail -20 build.log
    exit 1
fi
