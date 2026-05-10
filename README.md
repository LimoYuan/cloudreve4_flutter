# Cloudreve4 Flutter

[![Flutter](https://img.shields.io/badge/Flutter-3.41.6-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11.4-blue?logo=dart)](https://dart.dev)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

> 🚀 基于 Flutter 的 Cloudreve v4 第三方客户端，提供移动端便捷Cloudreve管理体验

---

## 📖 项目简介

Cloudreve4 Flutter 是一个功能丰富的云存储客户端，支持文件上传、下载、管理和分享。针对 Cloudreve v4 API 进行了基本完整适配和优化。

### ✨ 特性亮点

- 🎯 现支持的功能基本完整适配 Cloudreve v4 API
- 📱 跨平台支持（Android / Linux / Windows / Web）
- 🎨 现代化 Material Design 3 界面
- ⚡ 支持断点续传和下载进度监听
- 🔐 安全的 Token 认证机制

## 📸 截图

<table>
  <!-- 第一行：3个截图 -->
  <tr>
    <td align="center">
      <img src="screenshots/home.jpg" width="250"/><br/>
      <sub>home</sub>
    </td>
    <td align="center">
      <img src="screenshots/markdown.jpg" width="250"/><br/>
      <sub>markdown</sub>
    </td>
    <td align="center">
      <img src="screenshots/pdf.jpg" width="250"/><br/>
      <sub>pdf</sub>
    </td>
  </tr>
  <!-- 第二行：3个截图 -->
  <tr>
    <td align="center">
      <img src="screenshots/code.jpg" width="250"/><br/>
      <sub>code</sub>
    </td>
    <td align="center">
      <img src="screenshots/share.jpg" width="250"/><br/>
      <sub>share</sub>
    </td>
    <td align="center">
      <img src="screenshots/offline-download.png" width="250"/><br/>
      <sub>offline-download</sub>
    </td>
  </tr>
</table>

## 🎬 视频演示

[<img src="screenshots/music.jpg" width="200" title="点击观看 B 站视频演示"/>](https://www.bilibili.com/video/BV1EjZcBCEp7)

---

## 🛠️ 技术栈

| 组件 | 版本 |
|------|------|
| Flutter | 3.41.6 |
| Dart | 3.11.4 |
| 后端 API | Cloudreve v4.15 |

**开发环境详情：**

```
Debia
Flutter 3.41.6 • channel stable
Framework • revision db50e20168 • 2026-03-25
Dart 3.11.4 • DevTools 2.54.2
```

**构建环境详情：**

```
Android: compileAPI: 36, targetAPI: 36, miniAPI: 34
Windows: 11
Linux: Debian 12
```

📚 [API 文档](https://cloudrevev4.apifox.cn/)

---

## 📋 功能状态

### ✅ 基础功能

| 功能模块   | 状态 | 说明                        |
|--------|------|---------------------------|
| 用户登录   | ✅ | 自定义服务器, Token 认证、持久化      |
| 文件列表   | ✅ | 列表/网格双视图                  |
| 刷新列表   | ✅ | 增量更新                      |
| 全屏手势   | ✅ | 右侧左滑返回上级目录, 根目录提示退出       |
| 文件下载   | ✅ | 原生/浏览器双实现、进度监听、断点续传、后台下载  |
| 文件上传   | ✅ | 进度展示、分片上传<服务端需要开启>        |
| 删除文件   | ✅ | 删除文件                      |
| 重命名    | ✅ | 重命名文件                     |
| 移动复制   | ✅ | 移动/复制文件, 添加文件夹选择器对话框      |
| 我的分享   | ✅ | 完整的分享功能, 包括创建,删除,管理列表,编辑等 |
| 找回密码   | ✅ | 使用邮箱找回密码 (依赖控制台STMP可用性)   |
| 用户注册   | ✅ | 使用邮箱注册新用户 (依赖控制台允许注册新用户)  |
| 回收站    | ✅ | 文件恢复/彻底删除                 |
| WebDav | ✅ | 增删改查(硬编码查50条)             |
| 文件搜索   | ✅ | 全局搜索功能, 点击跳转到对应目录         |
| 设置页面   | ✅ | 增加多个实用的设置项                |
| 离线下载   | ✅ | 离线下载(依赖服务端aria2可用)        |
| 缩略图    | ✅ | 网格布局缩略图懒加载支持              |

>   文件下载
>   原生/浏览器双实现原因:
>
>   >   ~~选型使用了 `flutter_downloader` 来实现Android后台下载, 避免切换后台下载异常, 但这玩意儿不支持跨平台, 所以PC端就实现了获取文件url地址在浏览器打开进行下载; 正常应该选用 `background_downloader`~~
>
>   文件上传
>
>   >   看后端接口文档, 必须要按分片顺序上传, 看着是不支持多分片并发上传, 差点意思, 效率不高.

------

### ✅  设置页面

| 功能模块 | 状态 | 说明                                  |
|------|----|-------------------------------------|
| 个人资料 | ✅  | 修改昵称和头像                             |
| 安全设置 | ✅  | 修改密码/2FA等                           |
| 快捷入口 | ✅  | 概览页快捷入口设置, 默认4个, 支持新增修改和调整顺序        |
| 文件偏好 | ✅  | 历史版本开关, 视图同步, 个人主页分享链接可见性           |
| 应用设置 | ✅  | 深色模式/主题/语言/gravatar镜像/下载设置/缓存/日志管理等 |
| 关于   | ✅  | APP信息                               |

> Cloudreve 的控制面板实在是太复杂了, 本来打算实现一些user资料等相关的设置, 后来思虑再三, 发现其实也没这么强需求, 索性就想到啥加啥

-----

### ✅ 预览模块

| 功能模块 | 状态 | 说明 |
|----------|------|------|
| 图片预览 | ✅ | 全平台支持, win/linux 支持CTRL+鼠标滚轮缩放,双击恢复,平滑动画 |
| PDF预览 | ✅ | 全平台支持, 支持缩放, 选中文字复制等 |
| 音频预览 | ✅ | 全平台支持流式播放, 算好看的播放器UI, 进度条, 暂停, 快进/退10秒 |
| 视频预览 | ✅ | 全平台支持流式播放, 暂停, 调整音量, 全屏, 增加倍速支持 |
| 文本预览 | ✅ | 全平台支持, 189中语言代码高亮, SourceCodePro等宽字体, 一键复制 |
| MD预览 | ✅ | 全平台支持, 类github风格, TOC, 暗色模式支持.(dark缺陷) |

> 音视频预览库底层是 mpv 提供编解码能力, 理论上 mpv 支持的格式均支持, 具体没有实测;
>
> (待改进)视频预览进度条内嵌: MaterialVideoControlsTheme ->  MaterialVideoControls
>
> 文本预览现在是一次性渲染, 大文件会有性能问题, 如果借用listview来优化, 会丢失代码高亮, 暂时保持现阶段的情况, 另外应该也没啥大文本文件预览的场景

### 🚧 开发中

| 功能模块        | 进度 | 说明                         |
|-------------|------|----------------------------|
| ~~文件预览~~    | ✅ | 图片/文档/视频等预览(核心功能基本完成)      |
| ~~设置页面~~    | ✅ | 用户信息, 2FA等                 |
| ~~桌面端托盘~~   | ✅ | 桌面端托盘                      |
| ~~桌面端原生下载~~ | ✅ | 统一为 `background_downloader` |
| ~~我的页面~~    | ✅ | 我的页面                       |
| ~~批量C&M~~   | ✅ | 批量移动/复制                    |

### 📝 待优化

- [x] SnackBar 样式美化 (`oktoast`)
- [x] 错误/提示优化 (重构所有SnackBar为okToast)
- [x] 重构所有开发过程中的`debugPrint`为 `logger` 库
- [x] Windows/Linux平台使用`background_downloader`替代`flutter_downloader`下载, 增加下载速度显示
- [x] ListView 似乎还是完整重绘, 上传插值似乎也还是在完整重绘


### 🚧 待重构
| 功能模块                    | 进度 | 说明                                                                        |
|-------------------------|----|---------------------------------------------------------------------------|
| UI                      | ✅  | windows/linux/Android phone&pad 完整ui重构                                    |
| `background_downloader` | ✅  | flutter_downloader ->  background_downloader 全平台统一下载管理, 支持后台, 断点续传, 自动恢复等 |
| 搜索                      | ✅  | 移除旧搜索, 实现新版本支持实时搜索, 搜索历史, 搜索防抖; 优化搜索结果点击跳转                                |

---

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.41.6
- Dart SDK >= 3.11.4
- Cloudreve v4 后端服务

### 安装依赖

```bash
flutter pub get
```

### 运行项目

```bash
flutter run  # pdf 和 音视频会再构建过程中下载github上的依赖,自行解决网络问题
```

### 构建发布

```bash
# Android
flutter build apk --release
# Linux
flutter build -d linux --release
# windows
flutter build -d windows --release
```

---

## 📬 联系方式

- 📧 问题反馈：提交 Issue
- 💬 讨论交流：无

---

## 👏 捐赠/赞赏

对于一个完全没有android+flutter任何基础的萌新, 磨难是空前的; 虽然70%的功劳都是ai的, 但是如果这个项目为你带来帮助，请给一个 ⭐️ Star 支持！

如果觉得我实在是太肝(各种andorid+跨平台的问题抠脑壳, 实在肝不动了), 晚上两三点还在疯狂调试(第二天还要当牛马), 想要给我加鸡腿; 欢迎扫描下方二维码通过支付宝赞赏，请我喝杯咖啡☕！


| 支付宝 | 微信 |
| :---: | :---: |
| <img src="screenshots/ali-support-us.png" width="180" /> | <img src="screenshots/wechat-support-us.png" width="180" /> |

---

## ⚖️ 开源协议 (License)

本项目采用 **AGPL-3.0 (GNU Affero General Public License v3.0)** 协议开源。

### 核心约束：
1. **传染性**：如果你修改了本项目代码并重新发布，你的项目也必须以 AGPL-3.0 协议开源。
2. **云端公开声明**：如果你在服务器/云真机等上运行本项目并向公众提供网络服务（网盘服务），你必须向用户公开你所使用的源代码（包括任何修改）。
3. **禁止闭源商业化**：未经授权，禁止将本项目代码闭源后作为商业产品销售。

详情请参阅项目根目录下的 [LICENSE](./LICENSE) 文件。

---

