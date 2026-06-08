#!/bin/bash

### fastforge 不好用, 还是手写吧
set -e

function build_linux_dependencies() {
    # 检查 rustc 和 cargo 是否都在 PATH 中
    if ! command -v rustc &> /dev/null || ! command -v cargo &> /dev/null; then
        echo "⚠️ 未检测到 Rust 环境，准备安装..."

        # 尝试加载可能已存在但未生效的环境变量
        if [ -f "$HOME/.cargo/env" ]; then
            source "$HOME/.cargo/env"
        fi

        # 再次检查，如果还是没有，则进行安装
        if ! command -v rustc &> /dev/null; then
            echo "正在通过 rustup 安装 Rust..."
            # -y 表示自动化安装，不询问用户确认
            # --default-toolchain stable 确保安装稳定版
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            
            # 立即在当前 shell 进程中激活 Rust
            source "$HOME/.cargo/env"
        fi
    else
        echo "✅ Rust 环境已就绪: $(rustc --version)"
    fi

    echo "正在安装 Linux 构建依赖..."
    sudo apt upgrade -y
    sudo apt install -y libsqlite3-dev libmpv-dev libgtk-3-dev libglib2.0-dev libcanberra-gtk3-dev libcanberra-gtk3-dev libpango1.0-dev libcairo2-dev libcairo2-dev libpulse-dev libayatana-appindicator3-dev libwpewebkit-2.0-dev libwpebackend-fdo-1.0-dev libsecret-1-dev libfuse3-dev libasound2-dev ninja-build cmake pkg-config build-essential
}

function linux_flutter_plugin_magick() {
    # Get current flutter mirror 
    FLUTTER_MIRROR=$(grep 'url:' pubspec.lock | head -n 1 | sed 's|.*url: "https://\(.*\)"|\1|')
    BASE_PUB_CACHEDIR="$HOME/.pub-cache/hosted/${FLUTTER_MIRROR}"
    echo "🧙‍♂️ Flutter mirror cache path: ${BASE_PUB_CACHEDIR}"
    ## magick tray_manager ##
    echo "🧙‍♂️ 尝试为 tray_manager 添加补丁..."
    # 1. 拼接完整的插件 CMake 路径
    TARY_MANAGER_VERION=$(grep -A 8 'tray_manager:' pubspec.lock | grep 'version:' | cut -d'"' -f2)
    TARY_MANAGER_PATH_CMAKE="${BASE_PUB_CACHEDIR}/tray_manager-${TARY_MANAGER_VERION}/linux/CMakeLists.txt"
    echo "🧙‍♂️ 获取 tray_manager CMakeLists.txt 路径: ${TARY_MANAGER_PATH_CMAKE}"
    # 2. 在文件存在且不包含该定义时进行 patch
    if [ -f "$TARY_MANAGER_PATH_CMAKE" ]; then
        if ! grep -q "deprecated-declarations" "$TARY_MANAGER_PATH_CMAKE"; then
            echo "🧙‍♂️ 正在为 tray_manager 注入补丁..."
            # 使用 sed 在 project( 行后插入定义
            sed -i '/project(/a add_definitions(-Wno-error=deprecated-declarations)' "$TARY_MANAGER_PATH_CMAKE"
        else
            echo "✅ tray_manager 补丁已存在，跳过注入。"
        fi
    else
        echo "⚠️ 警告：未找到路径 $TARY_MANAGER_PATH_CMAKE"
    fi

    ## magick flutter_inappwebview ## 
    echo "🧙‍♂️ 尝试为 flutter_inappwebview 添加补丁..."
    INAPPWEBVIEW_LINUX_VERION=$(grep -A 8 'flutter_inappwebview_linux:' pubspec.lock | grep 'version:' | cut -d'"' -f2)
    INAPPWEBVIEW_LINUX_PATH_CC="${BASE_PUB_CACHEDIR}/flutter_inappwebview_linux-${INAPPWEBVIEW_LINUX_VERION}/linux/in_app_webview/in_app_webview.cc"
    echo "🧙‍♂️ 获取 flutter_inappwebview_linux .cc 路径: ${INAPPWEBVIEW_LINUX_PATH_CC}"

    if [ -f "$INAPPWEBVIEW_LINUX_PATH_CC" ]; then
        # 检查是否已经修改过（搜索注入的 FALSE; //）
        if ! grep -q "hasColor = FALSE; //" "$INAPPWEBVIEW_LINUX_PATH_CC"; then
            echo "🧙‍♂️ 正在施展 WebView 透明背景黑魔法..."
            sed -i 's/gboolean hasColor = webkit_web_view_get_theme_color/gboolean hasColor = FALSE; \/\/ /g' "$INAPPWEBVIEW_LINUX_PATH_CC"
        else
            echo "✅ WebView 透明补丁已存在，无需重复施法。"
        fi
    else
        echo "⚠️ 找不到文件: $WEBVIEW_CC_PATH"
    fi
}

function build_linux_release() { 

    build_linux_dependencies

    flutter pub get

    linux_flutter_plugin_magick

    # 1. 基础变量配置
    APP_NAME="cloudreve4"
    PROJECT_DIR=$(pwd)
    FLUTTER_BUNDLE="$PROJECT_DIR/build/linux/x64/release/bundle"
    PKG_DIR="$PROJECT_DIR/dist/debian"
    # 获取版本号
    RAW_VERION=$(grep '^version:' pubspec.yaml | sed 's/version: //;s/\"//g;s/ //g' | tr -d '\r')
    # debian 版本号
    DebVersion=$(echo $RAW_VERION | sed 's/+/-/g')

    # 2. 编译 Linux 版本
    echo "正在编译 Flutter Linux Release 版本..."
    flutter build linux -v --release

    # 3. 创建临时目录结构
    if [ -d "$PKG_DIR" ]; then
      echo "目录已存在，清楚旧的debian构建产物 $PKG_DIR"
      rm -rf "$PKG_DIR"
    fi

    echo "正在创建目录结构..."
    mkdir -p "$PKG_DIR/opt/$APP_NAME"
    mkdir -p "$PKG_DIR/usr/bin"
    mkdir -p "$PKG_DIR/usr/share/applications"
    mkdir -p "$PKG_DIR/DEBIAN"

    # 4. 安装到 /opt
    cp -rf "$FLUTTER_BUNDLE/"* "$PKG_DIR/opt/$APP_NAME/"

    # 5. 在 /usr/bin 创建软链接，方便终端直接输入命令启动
    ln -sf "/opt/$APP_NAME/${APP_NAME}_flutter" "$PKG_DIR/usr/bin/$APP_NAME"

    # 依赖项
    # - libsqlite3-0
    # # 必须：media_kit 播放视频的核心依赖
    # - libmpv-dev
    # - libmpv2
    # # 必须：Flutter Linux 应用的基础图形库
    # - libgtk-3-0
    # - libglib2.0-0
    # - libcanberra-gtk3-module
    # # 建议：涉及 PDF 渲染或某些窗口特性
    # - libpango-1.0-0
    # - libcairo2
    # # 建议：多媒体应用常见的音频与底层依赖
    # - libasound2
    # - libpulse0
    # # 托盘 tray_manager
    # - libayatana-appindicator3-1, 
    # # windows/linux webview - flutter_inappwebview 
    # - libwpewebkit-2.0-1, 
    # - libwpebackend-fdo-1.0-1, 
    # - libsecret-1-0, 
    # # 同步引擎镜像 feature 必须
    # - fuse3, 
    # - ## libfuse3-3

    APP_DEPENDS='libsqlite3-0, libmpv2, libcanberra-gtk3-module, libasound2, libpulse0, libayatana-appindicator3-1, libwpewebkit-2.0-1, libwpebackend-fdo-1.0-1, libsecret-1-0, fuse3'

    # 6. 写入控制文件 
    cat <<EOE | tee "$PKG_DIR/DEBIAN/control"
Package: ${APP_NAME}-flutter
Description: A GUI client built using Cloudreve V4 and Flutter.
Source: https://github.com/LimoYuan/cloudreve4_flutter
Version: ${DebVersion}
Architecture: amd64
Section: utils
Priority: optional
Maintainer: aeno yuan705791627@gmail.com
EOE

    # 应用依赖
    echo "🔍 正在分析二进制文件依赖..."
    ln -sf "$PKG_DIR/DEBIAN" "$PKG_DIR/debian"
    cd ${PKG_DIR} 
    
    RAW_DEPENDS=$(dpkg-shlibdeps -l./opt/cloudreve4/lib/ -O ./opt/cloudreve4/cloudreve4_flutter 2>/dev/null | sed 's/shlibs:Depends=//')
    
    rm -rf "$PKG_DIR/debian" && cd - 
    echo "✅ 二进制依赖 RAW: $RAW_DEPENDS"
    echo "✅ 完整依赖"
    echo "Depends: ${RAW_DEPENDS}, ${APP_DEPENDS}" | tee -a "$PKG_DIR/DEBIAN/control"
    echo
    # 7. 图标和桌面入口
    cat <<EOT | tee "$PKG_DIR/usr/share/applications/$APP_NAME.desktop"
[Desktop Entry]
Name=Cloudreve4
Exec=/usr/bin/$APP_NAME
Icon=/opt/$APP_NAME/data/flutter_assets/assets/images/app_logo.png
Type=Application
Categories=Network;
Terminal=false
EOT

    # 刷新桌面数据库，让 .desktop 文件立即生效
    cat <<EOF | tee "$PKG_DIR/DEBIAN/postinst" "$PKG_DIR/DEBIAN/postrm" 
#!/bin/sh
set -e
update-desktop-database -q
exit 0
EOF

    # 8. 修正权限 (必须步骤，确保系统能读取图标和执行程序)
    chmod +x "$PKG_DIR/DEBIAN/postinst" "$PKG_DIR/DEBIAN/postrm" 
    find "$PKG_DIR/opt/$APP_NAME" -type d -exec chmod 755 {} +
    find "$PKG_DIR/opt/$APP_NAME" -type f -exec chmod 644 {} +
    chmod +x "$PKG_DIR/opt/$APP_NAME/${APP_NAME}_flutter"

    # 9. 打包
    OUTPUT_NAME="cloudreve4_flutter_v${DebVersion}_linux_amd64.deb"
    dpkg-deb --root-owner-group --build "$PKG_DIR" "${PKG_DIR}/$OUTPUT_NAME"

    echo "--------------------------------------"
    echo "✅ 构建完成！"
    echo "安装包已生成: $OUTPUT_NAME"
    echo "安装命令: sudo apt install ${PKG_DIR}/${OUTPUT_NAME}"
}

function build_sync_core() {
    echo "🦀 添加 Rust Android abi平台构建支持"
    rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android

    echo "🦀 进入 Rust sync_core 目录"
    cd native 
    # cargo clean
    echo "🦀 正在编译 Rust 核心库 (arm64-v8a)..."
    cargo ndk -t aarch64-linux-android build --release

    echo "🦀 正在编译 Rust 核心库 (armeabi-v7a)..."
    cargo ndk -t armv7-linux-androideabi build --release

    echo "🦀 正在编译 Rust 核心库 (x86_64)..."
    cargo ndk -t x86_64-linux-android build --release

    echo "🦀 sync_core 构建完成, 准备同步到 Android 项目"
    
    cd ..

    LIB_DEST="android/app/src/main/jniLibs"
    
    if [ -d "$LIB_DEST" ]; then
      echo "🦀 目录已存在，清理旧的jniLibs"
      # rm -rf "$LIB_DEST"
    fi

    mkdir -p "$LIB_DEST/arm64-v8a"
    mkdir -p "$LIB_DEST/armeabi-v7a"
    mkdir -p "$LIB_DEST/x86_64"

    cp -f native/target/aarch64-linux-android/release/libsync_core.so "$LIB_DEST/arm64-v8a/"
    cp -f native/target/armv7-linux-androideabi/release/libsync_core.so "$LIB_DEST/armeabi-v7a/"
    cp -f native/target/x86_64-linux-android/release/libsync_core.so "$LIB_DEST/x86_64/"
    
    echo "✅ 同步完成！.so 已放入 jniLibs 目录。当前架构分布..."
    tree -L 2 "$LIB_DEST"
}

function build_android_release() { 

    build_sync_core
    
    echo "Android Release 构建开始..."

    PKG_DIR="$(pwd)/dist/android"

    
    if [ -d "$PKG_DIR" ]; then
      echo "目录已存在，清理旧的android构建产物 $PKG_DIR"
      rm -rf "${PKG_DIR}"
    fi

    echo "正在编译 Flutter Android Release ..."
    flutter build apk -v --release --split-per-abi
    ls -alh "$(pwd)/build/app/outputs/apk/release"

    mkdir -p "${PKG_DIR}"
    find "$(pwd)/build/app/outputs/apk/release" -name "*.apk" -exec cp {} "${PKG_DIR}" \;
    echo "Android Release 编译完成: ${PKG_DIR}"
}

function main() {
    case $1 in
        linux)
            build_linux_release
            ;;
        apk)
            build_android_release
            ;;
        rs)
            build_sync_core
            ;;
        all)
            build_linux_release
            build_android_release
            ;;
        *)
            echo "参数错误，使用：linux, apk, rs, all"
            echo '用法：$0 {linux|apk|rs|all}'
            ;;
    esac
}
 
main $1