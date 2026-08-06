# FluidSur KDE 主题

FluidSur 是由 FluidSur Project 独立设计、维护和发布的 KDE Plasma 主题，提供统一的玻璃质感、窗口装饰、壁纸、中文界面以及电源和性能组件。

项目地址：https://github.com/ipiggyzhu/FluidSur-kde

## 包含内容

- Plasma 全局主题：`FluidSur`、`FluidSur-alt`、`FluidSur-dark`
- Plasma 桌面主题、配色方案、Aurorae 窗口装饰和 Kvantum 样式
- FluidSur 壁纸、登录界面（SDDM）和启动画面资源
- 完整的 FluidSur、FluidSur-light、FluidSur-dark 图标主题与自包含光标主题
- 分离数字时钟、电源小组件、紧凑性能监控表盘和中文翻译
- GTK 2/3/4 主题（`gtk/`），让 GTK 应用的窗口按钮跟 KDE 侧保持同一套样式
- Firefox 主题（`firefox/`），通过 userChrome.css 让浏览器一并 macOS 化

## 安装

解压源码后，在源码根目录运行：

```sh
./install.sh
```

这会安装到当前用户的 `~/.local/share` 和 `~/.config/Kvantum`，不需要 root 权限。系统范围安装使用：

```sh
sudo ./install.sh
```

可选参数：

```sh
./install.sh --color dark
./install.sh --window opaque
./install.sh --window sharp
```

`--sharp` 和 `--opaque` 也可作为快捷写法。安装完成后，在“系统设置 → 外观 → 全局主题”中选择 FluidSur 变体；Kvantum 样式可在 `kvantummanager` 中选择 `FluidSur`。

### GTK 应用

`install.sh` 会自动构建并安装 GTK 主题，装到 `~/.themes`（system-wide 安装时装到 `/usr/share/themes`）。这一步需要 `sassc` 和 `glib-compile-resources`；缺少时会跳过并提示，不影响 KDE 部分的安装：

```sh
sudo dnf install sassc glib2-devel
```

装完在“系统设置 → 外观 → 应用程序风格 → 配置 GNOME/GTK 应用程序风格”里选择 `FluidSur-Light` 或 `FluidSur-Dark`，或者直接 `bash gtk/install.sh --apply`。GTK 应用不会热重载主题，需要重启应用才能看到变化。

> **不要手改 `~/.config/gtk-3.0/settings.ini` 里的 `gtk-theme-name`。** Plasma 自己另存了一份 GTK 主题记录并据此提供 XSETTINGS，手改只生效一半：XWayland 下的 GTK 应用仍用旧主题，原生 Wayland 的换新主题，两边长期不一致。

只装 GTK 部分或使用更多选项，见 [gtk/README.md](gtk/README.md)。跳过 GTK 部分：

```sh
./install.sh --no-gtk
```

**Chromium 系浏览器**只覆盖窗口按钮，且需要主动开启：在“设置 → 外观 → 自定义 Chrome → 窗框”中选 **GTK**（而不是 Chrome 内置样式）。Chrome 会构造一个 `headerbar.header-bar.titlebar button.titlebutton` 节点，正好命中本主题的窗口按钮规则，按钮样式就出来了；标签栏、工具栏和菜单仍是 Chrome 自己的样式。另一种做法是打开“使用系统标题栏和边框”，把整个窗框交回 KWin 走 Aurorae 装饰，代价是失去 Chrome 的标签页嵌入标题栏布局。

如果 GTK 应用（尤其 Chrome）的窗口按钮带一圈黑边、还偏大，那是旧版 kde-gtk-config 留下的 `~/.config/gtk-3.0/window_decorations.css` 在作祟——它以高于本主题的优先级把按钮图换成了 Qt 光栅化的 Aurorae 按钮，而 Qt 会给纯填充图形补上一支黑色画笔。按上面的方式重新选一次 GTK 主题即可清掉该文件，详见 [gtk/README.md](gtk/README.md)。

### Firefox

Firefox 同样自己绘制窗口按钮：它只从 GTK 读取按钮的**顺序和左右位置**，不读取外观，而过去用来关掉这一行为的 `widget.gtk.non-native-titlebar-buttons.enabled` 已经从源码中移除。所以光装 GTK 主题不足以让 Firefox 用上本主题的窗口按钮，必须走 userChrome.css。

因为要改写浏览器配置目录，这一步默认不执行，需要显式打开：

```sh
./install.sh --firefox            # 完整 macOS 化
./install.sh --firefox buttons    # 只改三个窗口按钮
```

装完重启 Firefox。安装器会自动在 `~/.mozilla/firefox`、`~/.config/mozilla/firefox`（Firefox 138 起的新位置）以及 Flatpak、Snap 四处查找配置文件目录；它不会清空你自己的 `user.js`，只维护其中一段带标记的区块，也不会杀掉正在运行的浏览器。更多选项和变体（`darker`、`adaptive`、`nord`）见 [firefox/README.md](firefox/README.md)。

### SDDM 登录界面

SDDM 需要 root 权限，单独运行：

```sh
sudo ./sddm/install.sh
```

卸载 SDDM 主题：

```sh
sudo ./sddm/install.sh --uninstall
```

### 卸载

```sh
./uninstall.sh
```

系统范围安装则使用 `sudo ./uninstall.sh`。

## 依赖与说明

- 主题主体支持 KDE Plasma 5 或 6；FluidSur 电源小组件和紧凑性能监控表盘面向 Plasma 6。
- SDDM 脚本会根据当前 Plasma 版本选择对应 QML 主题。
- 透明控件需要 Kvantum（发行版通常以 `kvantum` 或 `kvantum-manager` 提供）。
- 三套 FluidSur 图标资源随仓库提供，运行和安装时不从 WhiteSur 或其他第三方仓库下载；Breeze 和 Hicolor 仅作为系统缺失图标的标准回退。
- 安装脚本不会修改 KWin 的动画开关，也不会强制开启“吸入/吸出”效果。
- 不会打包当前用户的天气位置、面板实例或显示器布局，避免把个人配置带给其他用户。

## 许可与来源

FluidSur 由 FluidSur Project 独立维护。项目早期版本参考并使用了 WhiteSur KDE 的可再分发资源；完整图标集基于 GPL-3.0 的 WhiteSur Icon Theme 修改；`gtk/` 和 `firefox/` 组件基于 MIT 许可的 WhiteSur GTK Theme 修改，原始许可证保留在 `gtk/COPYING`。根目录 `LICENSE`、各组件许可证、图标目录中的原始许可证及 [NOTICE.md](NOTICE.md) 仍适用于对应文件。
