# 绷铁遗器一键分解

Windows 简体中文客户端的遗器整理工具。用 Reliquary 读取背包，在本机按 Fribbels 角色权重评分，只评估五星角色。支持低分自动标记弃置，以及每次 +3、重新评分后继续的自动强化。分解由玩家在游戏内确认。

## 下载 v1.4.0 测试版

**[下载 Windows ZIP](https://github.com/piqiumanager/hsr-relic-manager/releases/download/v1.4.0/hsr-relic-manager-v1.4.0-windows.zip)** · [版本发布页](https://github.com/piqiumanager/hsr-relic-manager/releases/tag/v1.4.0)

ZIP 只有 EXE 和中文说明，内置读取、评分、弃置与强化组件。不需要 Python、Node 或另下 Reliquary；界面需要微软 WebView2 Runtime。

![主界面：示例背包](docs/preview.png)

## v1.4 更新

- 新增真实游戏强化执行模块：查找胚子、进入强化页、选择材料规则、核实下一档等级、确认强化、读取新词条、重新评分。
- 每次 +3。未满级按平均满级潜力 ≥80 继续，+15 按当前分 ≥80 保留；低分只标记弃置。
- 允许经验材料和四星及以下遗器。自动置入前核对空材料槽，强化前再次核对材料范围与 +3 目标。
- 界面参考 MAA 的白底蓝色任务布局：左侧选择弃置或强化，右侧显示评分与状态。六位官网女性角色立绘作为淡色背景，每次打开更换，图片内置且无需联网。
- 延续百分比主属性修复、固定 1920×1080 布局和键盘遍历，不再需要手动校准。

**强化执行模块已接入 EXE；逻辑、OCR、服务交互与桌面启动已验证，真实游戏全流程尚未实测。本版为测试版，遇到识别不确定会停止。**

## 使用

1. 游戏设置为 **1920×1080 客户区、简体中文、PC 键鼠模式**，停在登录界面。
2. 打开 EXE，点“读取背包”，授权后进入游戏，等待读取与评分完成。
3. 左侧选择“低分弃置”或“胚子强化”，点“开始标记”或“开始强化”。工具使用默认快捷键 B 打开背包；改过快捷键时先手动进入遗器背包。
4. 首次可打开“仅预览”。弃置模式只核对候选；强化模式会进入强化页、准备材料并退出，不点击确认强化、不消耗材料。
5. 运行时保持游戏前台，不操作鼠标键盘；**F8** 或“停止”终止。最后自行检查弃置列表并确认分解。

自动强化仅处理评分结果中的高潜力胚子，要求未锁定、未装备、未弃置，等级为 +0/+3/+6/+9/+12。+0 胚子先试到 +3，再按 80 分判断。满级遗器不进入强化队列；原本低分的遗器可用弃置模式处理。

强化后的每一步都重新读取实际等级与副属性，不沿用旧分数。画面隐藏小数可能影响 80 分判断时，保留并停止。一次强化或弃置后，重新读取背包才能开始新任务。

弃置模式默认满级当前分 ≥75；胚子平均潜力 ≥70 且上限 ≥85，可在评分设置修改。**强化执行固定使用 80 分门槛**。分数为属性潜力百分比，并非整队伤害评级。锁定、装备的遗器仍显示评分，但跳过自动操作。

背包数据在本机处理，不上传账号数据。详细操作见[使用说明](使用说明.txt)，验证范围见[VALIDATION](docs/VALIDATION.md)。

背景采用[星穹铁道官网](https://sr.mihoyo.com/main?nav=character)的三月七、姬子、卡芙卡、流萤、知更鸟和黄泉立绘，随程序内置并以低不透明度显示。图片原始地址与版权声明见 [credits.json](source/backgrounds/credits.json)。界面布局参考 [MAA](https://github.com/MaaAssistantArknights/MaaAssistantArknights)。

## 开发

```powershell
node source/repack.mjs
node scripts/test-engine.cjs
node scripts/test-import-main.cjs
node scripts/test-mark-plan.cjs
node scripts/test-upgrade-flow.cjs
node scripts/test-upgrade-scoring.cjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-upgrade-core.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-upgrade-bridge.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File desktop/build.ps1
```

构建固定版本并校验 SHA256 的微软 WebView2 SDK 与 Reliquary 官方组件，输出 EXE 及 ZIP 至 dist。源码与依赖许可随 EXE 内置。

## 相关项目与许可

整体 [AGPL-3.0](LICENSE)。第三方声明见 [licenses](licenses)。

- [Fribbels](https://github.com/fribbels/hsr-optimizer)：评分核心与角色权重，MIT。
- [Reliquary Archiver](https://github.com/IceDynamix/reliquary-archiver)：背包读取，MIT。
- [HSR-Scanner](https://github.com/kel-z/HSR-Scanner)：库存区域与键盘遍历参考，GPL-3.0；修改说明见来源记录。
- [三月七小助手](https://github.com/moesnow/March7thAssistant)：参考固定画面区域与界面确认的自动化思路。
- [StarRailRes](https://github.com/Mar-7th/StarRailRes)：遗器单件名称资料，AGPL-3.0。

本项目与游戏官方无隶属关系，不执行分解确认。
