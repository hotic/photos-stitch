<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="拼成长图">
</p>
<h1 align="center">拼成长图</h1>
<p align="center">
  把多张图片按顺序拼成一张竖向长图的 macOS 小工具。
  <br>
  <a href="README.md">English</a>
</p>

<table>
  <tr>
    <td align="center"><strong>访达操作</strong></td>
    <td align="center"><strong>相册操作</strong></td>
  </tr>
  <tr>
    <td><img src="Resources/screenshots/finder.png" alt="从访达拼图" width="400"></td>
    <td><img src="Resources/screenshots/photos.png" alt="从相册拼图" width="400"></td>
  </tr>
</table>

## 功能亮点

- **智能输出目标**：从 Photos 进来的图片拼完自动导回 Photos；从 Finder / 命令行进来的图片保存在源文件旁边，并在 Finder 中高亮显示
- **Photos 右键直达**：挂载到 macOS Photos 的"编辑工具 / Edit With"菜单，选图即拼
- **Finder 多入口**：在 Finder 里多选图片，可以用"打开方式 → 拼成长图"或右键"服务 → 拼成长图"
- **自动继承时间戳**：新图默认继承第一张输入图片的拍摄时间（EXIF / TIFF / PNG / 文件属性），导回 Photos 不会跑到最新
- **多批次自动合并**：Photos 有时会把一次多选拆成多批 `open` 事件，app 会在短窗口内自动合并
- **HEIC 优先输出**：优先生成 HEIC 格式（体积更小），系统不支持时自动回退到 JPEG

## 系统要求

- macOS 13.0 (Ventura) 或更高版本

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `Sources/` | AppKit app 源码 |
| `Resources/Info.plist` | bundle、文档类型和 Finder Service 声明 |
| `Resources/*.lproj/` | 本地化字符串（英文 & 简体中文） |
| `scripts/build.sh` | 编译、打包、安装到 `~/Applications/` |
| `scripts/smoke_test.sh` | 生成样图并跑一遍 smoke test（不会导入 Photos） |

## 构建

```bash
./scripts/build.sh
```

构建完成后，app 会被安装到 `~/Applications/`。

## 使用

1. 在 Photos 里多选图片，右键"编辑工具"，找到"拼成长图"
2. 如果 Photos 这条链路只传进来 1 张图，就在 Finder 里选中多张图片，右键"服务 → 拼成长图"
3. 首次导回 Photos 时，系统会弹照片权限，放行即可

也可以直接通过命令行使用：

```bash
open -a ~/Applications/拼成长图.app photo1.jpg photo2.png photo3.heic
```

## 测试

```bash
./scripts/smoke_test.sh
```

这个测试不会往 Photos 真导图，而是把产物保存在临时目录里，最后打印输出文件路径和像素尺寸。
