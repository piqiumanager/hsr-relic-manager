# 绷铁遗器一键分解

Windows 简体中文客户端的遗器整理工具。按已收录五星角色的 Fribbels 权重评分，自动标记低分遗器，分解由玩家确认。

**[下载 v1.5.5 测试版：EXE＋中文说明](https://github.com/piqiumanager/hsr-relic-manager/releases/download/v1.5.5/hsr-relic-manager-v1.5.5-windows.zip)** · [发布页](https://github.com/piqiumanager/hsr-relic-manager/releases/tag/v1.5.5)

ZIP 内只有一个 EXE 和说明，模型与背景已内置，无需 Python、Node 或另下素材。

![主界面，示例背包](docs/preview.png)

## 新界面

紧凑圆角侧栏、两种任务切换、底部固定操作区和右侧角色立绘。评分明细与设置统一重新排版。

![角色背景选择](docs/gallery.png)

## 一键筛选

1. 游戏使用 **1920×1080 客户区、简体中文、PC 键鼠模式**，停在主界面或遗器背包。
2. 关闭旧工具，打开新 EXE，确认管理员授权。
3. 点击 **开始筛选并标记**，无需重新登录。

清理规则：

- **未满级平均满级潜力 <80：标记弃置。已锁定的先解锁，再核验并标记。**
- 平均潜力 ≥80：保留，不再要求同时满足理论上限。
- **+15 当前分 <80：标记弃置；达到 80 保留。**
- 已装备的低分遗器保留并单独提醒。锁定状态不明或不能可靠评分的跳过，并显示原因。

按目标五星中最高的平均满级潜力判断。画面隐藏小数使用可能值区间核验。旧版 70/85 设置会切换到本版规则。

“仅看评分”不会解锁或标记。开始筛选时逐件操作当前游戏，进度显示本次已标记数量及跳过原因。**F8** 或“停止”结束，分解在游戏中自行确认。

评分明细默认高分在前，支持当前分、平均潜力、理论上限排序，重复点击切换升降序。

![评分明细，示例背包](docs/sorting.png)

## 角色背景

内置 **59 张女性角色官网立绘**，包含镜流、符玄、阮·梅、黑天鹅、花火、银狼、布洛妮娅等。每次启动随机更换，不连续重复；也可在“角色背景”中搜索和选择。

右侧清晰立绘与左侧操作分开，默认不透明度 **82%**。点击人物旁的“换一张”切换，在“角色背景”中调节清晰度，选择会保存。图片全部从本机读取。完整名单和官网地址见 [credits.json](source/backgrounds/credits.json)。

## 逐件强化

点击“胚子强化”后直接点击“开始强化”，无需先读完整背包或重新登录。

逐件识别和评分，低于 80 先标记弃置。未满级平均满级潜力达到 80 的未锁定、未装备遗器，每次强化至下一档（+3、+6、+9、+12、+15）。每档都读回新属性并重新评分；掉到低分立即标记弃置，达到高分 +15 则保留。原本在 +7 等非整档等级的，先补到下一档，再逐档处理。

已锁定的低分件会解锁并弃置；强化模式会解锁未装备的高潜力胚子，再逐档强化。已装备的低分件单独提醒。识别异常时停止或跳过，不会把未确认的点击计入成功。

允许经验材料和未锁定、未装备的四星及以下遗器，禁止使用五星材料。强化前核验材料规则及目标等级，强化后核验身份、等级和词条。材料不足或无法核验时停止。工具只标记弃置，分解由玩家确认。

## 修复与验证

v1.5.5 修复标记图标变化掩盖翻页失败的问题，移动校验改为使用操作后的背包网格。数字识别组件发生异常或超时会停止，停止操作可中断等待，重试会重建组件。强化按钮改为“开始强化并弃置”，高分锁定胚子也能解锁后强化；未完成项目单独列出，存在未完成项时不会显示为全部完成。

流程为：一键弃置低分件，再一键强化并弃置，最后由玩家确认分解已弃置的遗器。处理范围内保留当前分达到 80 的 +15，已装备、状态不明和材料不足的情况单独处理。

此前新增副属性总强化次数校验，识别出的单条数值即使各自合法，总次数不符合等级时也会拒绝。评分回包绑定当前遗器与画面指纹；异常主属性、非有限数值和错误评分类型不能进入执行。强化还需同时核实评分下界达到 80。停止时已送达的评分不能继续执行，未保存完整的记录不能当作完整背包，退出进程会清除过期请求并显示原始错误。

此前已修复锁定按钮状态识别反向、快照保存崩溃以及出错后状态停留在等待评分的问题。清理与强化共用现场识别、评分和已确认弃置流程；强化后背包重排会重新遍历并更新数量。

23 组基础离线回归、1 组完整背包压力回归及 2 组浏览器界面测试通过，包含真实评分代码、文件通信、执行函数、完整模拟背包遍历和逐档强化。**本版尚未完成真实游戏中的解锁、弃置和材料消耗验证，仍为待游戏复测的测试版，不能视为无 BUG 保证。** 详情见 [验证记录](docs/VALIDATION.md)。

## 数据与开发

截图和背包在本机处理。界面需要 Microsoft WebView2 Runtime，启动时需要管理员授权。数据目录为 `%LOCALAPPDATA%\HSRRelicManager\data`，任务截图与操作记录在 `marker-runs`。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/prepare-ocr.ps1
node source/repack.mjs
node scripts/run-offline-tests.cjs
# 本机安装简体中文 OCR 时可运行额外识别回归：
node scripts/run-offline-tests.cjs --ocr
# 完整 3000 件混合背包与连续强化模拟：
node scripts/run-offline-tests.cjs --ocr --stress
powershell.exe -NoProfile -ExecutionPolicy Bypass -File desktop/build.ps1
```

浏览器集成测试 `scripts/test-live-ui.cjs` 需要 Playwright、Chrome 和独立测试服务，游戏操作接口均使用模拟响应。开发构建会下载并校验固定版本依赖，运行源码和构建脚本随 EXE 内置。

## 许可

整体 [AGPL-3.0](LICENSE)，第三方许可见 [licenses](licenses)。

- [Fribbels](https://github.com/fribbels/hsr-optimizer)：评分核心与角色权重，MIT。
- [Reliquary Archiver](https://github.com/IceDynamix/reliquary-archiver)：JSON 导入与保留的登录抓取接口，MIT；日常标记无需重登。
- [HSR-Scanner](https://github.com/kel-z/HSR-Scanner)：布局、导航和装备边框参考，GPL-3.0。
- [Tesseract.js](https://github.com/naptha/tesseract.js)、[Tesseract.js-core](https://github.com/naptha/tesseract.js-core)、[tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast)：离线数字识别，Apache-2.0。
- [StarRailRes](https://github.com/Mar-7th/StarRailRes)：遗器单件名称，AGPL-3.0。

角色美术来自星穹铁道官网，版权归米哈游及相关权利人，不适用代码许可。本项目与游戏官方无隶属关系。
