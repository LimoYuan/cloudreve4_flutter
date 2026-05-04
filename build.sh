#!/bin/bash

### fastforge 不好用, 还是手写吧

function build_linux_release() { 
    # 1. 基础变量配置
    APP_NAME="cloudreve4"
    PROJECT_DIR=$(pwd)
    FLUTTER_BUNDLE="$PROJECT_DIR/build/linux/x64/release/bundle"
    PKG_DIR="$PROJECT_DIR/dist/debian"
    # 获取版本号
    Version=$(grep '^version:' pubspec.yaml | cut -d ' ' -f 2 | tr -d '\r')

    # 2. 编译 Linux 版本
    echo "正在编译 Flutter Linux Release 版本..."
    flutter build linux -v --release

    # 3. 创建临时目录结构
    if [ -d "$PKG_DIR" ]; then
      echo "目录已存在，清楚旧的debian构建产物 $PKG_DIR"
    fi

    echo "正在创建目录结构..."
    mkdir -p "$PKG_DIR/opt/$APP_NAME"
    mkdir -p "$PKG_DIR/usr/bin"
    mkdir -p "$PKG_DIR/usr/share/applications"
    mkdir -p "$PKG_DIR/DEBIAN"

    # 4. 安装到 /opt
    cp -r "$FLUTTER_BUNDLE/"* "$PKG_DIR/opt/$APP_NAME/"

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
    # - libcanberra-gtk-module
    # - libcanberra-gtk3-module
    # # 建议：涉及 PDF 渲染或某些窗口特性
    # - libpango-1.0-0
    # - libcairo2
    # # 建议：多媒体应用常见的音频与底层依赖
    # - libasound2
    # - libpulse0

    # 6. 写入控制文件 
    cat <<EOE | tee "$PKG_DIR/DEBIAN/control"
Package: com.limo.cloudreve
Version: ${Version}
Section: utils
Priority: optional
Architecture: amd64
Depends: libsqlite3-0, libmpv-dev, libmpv2, libgtk-3-0, libglib2.0-0, libcanberra-gtk-module, libcanberra-gtk3-module, libpango-1.0-0, libcairo2, libasound2, libpulse0, libayatana-appindicator3-dev
Maintainer: Aeno yuan705791627@gmail.com
Description: A GUI client built using Cloudreve V4 and Flutter.
EOE

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
    OUTPUT_NAME="cloudreve4_flutter_v${Version}_linux_amd64.deb"
    dpkg-deb --build "$PKG_DIR" "${PKG_DIR}/$OUTPUT_NAME"

    echo "--------------------------------------"
    echo "✅ 构建完成！"
    echo "安装包已生成: $OUTPUT_NAME"
    echo "安装命令: sudo apt install ./${OUTPUT_NAME}"
}

function build_android_release() { 
    PKG_DIR="$(pwd)/dist/android"
    
    if [ -d "$PKG_DIR" ]; then
      echo "目录已存在，清理旧的android构建产物 $PKG_DIR"
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
        all)
            build_linux_release
            build_android_release
            ;;
        *)
            echo "参数错误，使用：linux, apk, all"
            echo '用法：$0 {linux|apk|all}'
            ;;
    esac
}
 
main $1
