# 绷铁遗器一键分解

Windows 本地中文客户端的遗器清理工具。用 Reliquary 读取背包，按 Fribbels 角色权重计算分数，只评估五星角色，只保留极高分和高潜力遗器。低分遗器可自动标记弃置，分解由玩家在游戏内确认。

## 下载 v1.3.0 测试版

**[下载 Windows ZIP](https://github.com/piqiumanager/hsr-relic-manager/releases/download/v1.3.0/hsr-relic-manager-v1.3.0-windows.zip)** · [版本发布页](https://github.com/piqiumanager/hsr-relic-manager/releases/tag/v1.3.0)

ZIP 仅包含 EXE 和中文说明。内置读取与评分组件，不需要 Python、Node 或另下 Reliquary。界面使用微软 WebView2 Runtime。

## 这版改了什么

- 修复百分比主属性被误读为固定值的问题。现在根据遗器部位正确识别 HP/ATK/DEF 主属性；锁定、装备的遗器也照常评分。
- 分开显示“已评分”“有评分但受保护”“数据异常无评分”，明细不再混淆保护状态与评分缺失。
- 取消 14 步点选校准，改用固定 1920×1080 客户区布局、界面检查和键盘遍历。
- 首页收为读取背包、开始标记和停止，完整评分表及门槛设置放入单独窗口。

**评分导入已通过本机实际背包回归。新版游戏内自动定位仍需实机预览验证，发布为测试版，遇到画面或识别不确定会停止或跳过。**

## 使用

1. 游戏设为 **1920×1080、中文界面、PC 键鼠模式**，停留在登录界面。
2. 打开 EXE，点“读取背包”，授权后进入游戏，等待读取和评分完成。
3. 首次可勾选“仅识别预览”。点“开始标记”后，工具会尝试用 B 打开背包并切换到遗器，不需要画框。
4. 运行时不操作鼠标键盘，按 **F8** 或“停止”终止。自定义背包快捷键的玩家请先手动打开遗器背包。
5. 结束后在游戏内检查弃置列表，自行确认分解。未识别、锁定、已装备或已弃置的遗器保持不动。

默认满级当前分 ≥75；胚子平均潜力 ≥70 且上限 ≥85。任意目标五星达标即可保留。评分是遗器属性潜力百分比，仍需结合整队配装和速度调整。

启动会重算本机上次背包的评分；自动标记仍需本次新读取快照。背包数据在本机处理，不上传账号数据。详见[使用说明](使用说明.txt)。

![主界面](docs/preview.png)

## 开发

```powershell
node source/repack.mjs
node scripts/test-engine.cjs
node scripts/test-mark-plan.cjs
node scripts/test-import-main.cjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-layout.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File desktop/build.ps1
```

构建使用固定版本并校验 SHA256 的微软 WebView2 SDK 与 Reliquary 官方组件，输出 EXE 及 ZIP 至 dist。源码与全部依赖许可随 EXE 内置，也在本仓库提供。

## 相关项目与许可

整体 [AGPL-3.0](LICENSE)。第三方声明见 [licenses](licenses)。

- [Fribbels](https://github.com/fribbels/hsr-optimizer)：评分核心与角色权重，MIT。
- [Reliquary Archiver](https://github.com/IceDynamix/reliquary-archiver)：背包读取，MIT。
- [HSR-Scanner](https://github.com/kel-z/HSR-Scanner)：库存区域坐标与键盘遍历参考，GPL-3.0，修改说明见来源记录。
- [三月七小助手](https://github.com/moesnow/March7thAssistant)：参考固定画面区域与界面确认的自动化思路，没有直接调用其清理规则。
- [StarRailRes](https://github.com/Mar-7th/StarRailRes)：遗器单件名称资料，AGPL-3.0。

本项目与游戏官方无隶属关系，不执行分解确认。

## 逐段强化原型

规则与状态流程见 source/upgrade-flow.js：每次 +3，未满级平均潜力 ≥80 继续，满级按当前分 ≥80 保留；低分仅标弃置。材料允许专用经验与未锁定、未装备的四星及以下遗器，禁止吞五星。

流程已通过模拟执行器测试，尚未接入真实游戏强化按钮与材料选择；本版 EXE 暂不具备自动强化功能。
