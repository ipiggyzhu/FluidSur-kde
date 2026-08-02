# FluidSur KDE 主题

FluidSur 是由 FluidSur Project 独立设计、维护和发布的 KDE Plasma 主题，提供统一的玻璃质感、窗口装饰、壁纸、中文界面以及电源和性能组件。

项目地址：https://github.com/ipiggyzhu/FluidSur-kde

## 包含内容

- Plasma 全局主题：`FluidSur`、`FluidSur-alt`、`FluidSur-dark`
- Plasma 桌面主题、配色方案、Aurorae 窗口装饰和 Kvantum 样式
- FluidSur 壁纸、登录界面（SDDM）和启动画面资源
- 完整的 FluidSur、FluidSur-light、FluidSur-dark 图标主题与自包含光标主题
- 分离数字时钟、电源小组件、紧凑性能监控表盘和中文翻译

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

FluidSur 由 FluidSur Project 独立维护。项目早期版本参考并使用了 WhiteSur KDE 的可再分发资源；完整图标集基于 GPL-3.0 的 WhiteSur Icon Theme 修改。根目录 `LICENSE`、各组件许可证、图标目录中的原始许可证及 [NOTICE.md](NOTICE.md) 仍适用于对应文件。
