# 星铁遗器整理助手

面向 Windows 本地中文客户端的遗器筛选工具。读取 Reliquary 背包数据，使用 Fribbels 属性评分，按五星角色的当前评分和强化潜力挑选遗器，并可在游戏内标记清理候选。

**当前版本：v1.2.0 实验版。游戏内自动标记尚未完成实机端到端验证，首次请先校准并运行“仅识别预览”。工具不会执行分解。**

## 下载

- **[直接下载 Windows 工具包](https://github.com/piqiumanager/hsr-relic-manager/releases/download/v1.2.0/hsr-relic-manager-v1.2.0-windows.zip)**
- [查看版本发布页](https://github.com/piqiumanager/hsr-relic-manager/releases)
- [下载校验值](https://github.com/piqiumanager/hsr-relic-manager/releases/download/v1.2.0/SHA256SUMS.txt)

下载 ZIP，解压后只有 **`星铁遗器整理助手.exe`** 和 **`使用说明.txt`**，双击 EXE 打开桌面窗口。内置读取组件，无需 Python、Node.js 或另下 Reliquary；界面使用系统 WebView2 Runtime，缺少时提供微软安装入口。

![示例背包界面](docs/preview.png)

## 快速使用

1. 把游戏停在登录界面，在工具里点击“一键整理”。内置官方 Reliquary v0.20.0 PktMon 组件并校验文件。接受管理员授权后，再点击进入游戏。
2. 读取完成后自动筛选。也可以直接拖入 Reliquary、HSR Scanner 或 Fribbels 导出的完整背包 JSON。
3. 选择“全部五星”“仅已拥有五星”或手动勾选五星角色，按需要调整评分门槛。
4. 如需自动标记，在游戏打开“背包 → 遗器”，选择五星，清除锁定/弃置状态筛选，并展开右侧详情。
5. 首次按提示校准位置，再把遗器列表滚动到顶部。先从“自动标记弃置”运行“仅识别预览”，核对后在“一键整理”里点“继续标记”。以后同一分辨率可复用校准。
6. 运行时保持游戏在前台，不要操作鼠标。按 **F8** 或工具中的“停止”结束任务。校准时也可按 Esc 取消。
7. 完成后在游戏中查看“已弃置”，检查后自行分解。

详细步骤见 [使用说明](使用说明.txt)。

## 默认筛选

只评估五星角色，五星遗器中的未强化胚子与已强化遗器一起筛选。

| 遗器状态 | 保留条件 |
| --- | --- |
| 已满级 | 任一目标五星角色的当前属性分 ≥75 |
| 未满级 | 同一目标五星角色的平均满级潜力 ≥70，且理论上限 ≥85 |

不按部位凑保留数量，不额外保留中低分速度鞋或充能绳。可以修改门槛和单个角色的属性权重。

分数是 0–100 的遗器属性潜力百分比，**不是整队伤害评分**。套装效果、速度调轴和队伍搭配仍需结合配装检查。理论上限不代表实际强化结果。

## 自动标记的范围

- 仅使用最近 30 分钟通过本工具“一键读取”得到的背包快照。
- 逐件核对遗器名称、套装、等级、主属性和副属性；点击前再次读取，点击后检查红色弃置状态。
- 跳过已锁定、已装备、已弃置、数据不完整或存在视觉歧义的遗器。
- 游戏失去焦点、尺寸改变、页面变化或标记无法确认时停止。
- **不解锁，不取消已有弃置，不强化，不分解，不点击最终确认。**

首次需要根据截图完成位置校准。分辨率或布局变化后重新校准。云游戏与英文界面暂不支持此标记模块。

## 本机数据

EXE 自动释放文件到 `%LOCALAPPDATA%\HSRRelicManager\app`，背包、校准和日志在同目录 `data` 中，浏览器配置在 `webview` 中。关闭桌面窗口会请求停止标记。

背包与截图在本机处理。运行中生成的 `captures/`、`marker-config/`、`marker-runs/` 和 `tools/` 不属于源码，不应上传到公开仓库。背包导出和会话文件可能包含账号 UID。

## 开发

源码包含前端、内置资料、PowerShell 服务和 C# 标记器。正常使用不需要开发环境。

使用 Node.js 18 或更高版本可重新生成单文件界面和运行评分测试：

```sh
node source/repack.mjs
node scripts/test-engine.cjs
node scripts/test-mark-plan.cjs
```

在 Windows PowerShell 中可测试匹配规则与本机中文 OCR：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-marker-core.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-marker-ocr.ps1
```

这些测试不向游戏发送输入。验证范围见 [独立验证记录](docs/VALIDATION.md)。

## 许可证与相关项目

整体按 [AGPL-3.0](LICENSE) 提供，完整源码在本仓库中。第三方许可与修改记录保留在 [licenses](licenses) 中。

- [Fribbels HSR Optimizer](https://github.com/fribbels/hsr-optimizer)：属性评分核心与角色权重，保留 MIT 许可。
- [Reliquary Archiver](https://github.com/IceDynamix/reliquary-archiver)：完整背包导出；不捆绑程序，首次读取时从官方发布页下载。
- [StarRailRes](https://github.com/Mar-7th/StarRailRes)：遗器单件名称资料，保留 AGPL-3.0 许可。

本项目与游戏官方无隶属关系，游戏名称和资料权利归原权利人所有。

## 构建 Windows EXE

Windows 10/11 自带的 .NET Framework 编译器可构建桌面程序。PowerShell 运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File desktop/build.ps1
```

首次构建会下载并校验固定版本的微软 WebView2 SDK 和 Reliquary 官方 EXE，输出到 `dist/`。ZIP 仅包含 EXE 与使用说明；GitHub Actions 使用同一脚本构建并发布。

星空图片：NASA [The Seven Sisters](https://www.nasa.gov/image-article/seven-sisters/)，按其[媒体使用指南](https://www.nasa.gov/nasa-brand-center/images-and-media/)使用。未使用第三方脚本的界面图片。
