import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const DesktopTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return WindowCaption(
      brightness: Theme.of(context).brightness,
      backgroundColor: Colors.transparent, // 透明背景，露出下面的组件颜色
      title: Row(
        children: [
          // 可以在这里放一个小 Logo
          Image.asset(
            'assets/icons/tray_icon.png',
            width: 20,
            height: 20,
          ),
          SizedBox(width: 10),
          const Text(
              "Cloudreve4_flutter",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoSansSC',
                fontSize: 13,
                fontWeight: FontWeight.w700
              )
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(32); // Windows 标准标题栏高度
}