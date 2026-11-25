# 致理楼外景

入口以[深圳大学心理学院的 C 座照片](https://psy.szu.edu.cn/en/images/ba1d0f55f4c605d9ad5a93fcd850442.jpg)为依据。画面里最值得对齐的是低横梁的上下缘、深灰柱之间的留白、白色楼梯的折线，以及蓝色院牌相对楼梯的位置。

楼群轮廓参照[深大建筑设计研究院的教育项目](http://www.suiadr.com/project?dd=10#project-id-p-cate46)中「理工科教学楼、实验与信息中心」的[庭院斜视](http://www.suiadr.com/u_file/fileUpload/2021-05/10/2021051077344.jpg)和[塔楼正视](http://www.suiadr.com/u_file/fileUpload/2021-05/10/2021051064218.jpg)。白色塔冠内凹，后方教学翼带弧度，玻璃厅架在立柱上。模型按比例目测，背面、景观及夜间灯光是创作推定。参考照片链接到原发布方。

## 制作方法

对照 [实景照片及各自可核对的细节](REFERENCES.md)。正面机位用横梁、柱脚和学院牌作标定点。B 座台阶的颜色另查彩照，东侧架空厅的实墙开窗另查庭院斜视。镜头之外的连接、内部进深和雨后光照按建筑关系推定。

此次外景采用ハヤシモン的制作顺序。作者先按目标图中器物的位置搭体块，再给主体做真实凹口，按材料区分跑水痕、底部泥污与边缘损耗，最后回到特写检查标识。这次把同一套顺序用于窗洞、楼梯和门廊。手持设备加载带米制 UV 和局部遮光的模型，摄影机位使用同一份建筑几何做 Cycles 渲染。石材颗粒、竖向水痕与墙脚返潮分别控制，植物和墙面的贴图由项目生成。[作者的体块与凹口](https://x.com/hayashimon1/status/2108913493156270544) · [按表面位置处理磨损](https://x.com/hayashimon1/status/2108913494783676442) · [印刷物细化](https://x.com/hayashimon1/status/2108913496369115560)

- 从固定机位对齐大体块和负空间之后再开窗。参考 Ian Hubert 的[建筑建模演示](https://www.youtube.com/watch?v=v_ikG-u_6r0)。本场景给主要窗洞建了窗台和退进深度，曲面教学翼按弧线排布可复用的立面单元。
- Anastasia Opara 展示了植被如何适应墙面以及拱洞的边界。本场景用花池轮廓约束灌木和叶簇的分布。[作者的 X 串文](https://x.com/anastasiaopara/status/1543163341513842690)和[可读展开版](https://threadreaderapp.com/thread/1543163341513842690.html)。
- Oskar Stålberg 说明了地形表现和玩法格可以使用不同的网格。对应到栖灵，场景中三个可选活动点单独保存，弧形建筑、铺地和楼梯可以各按现场造型连续展开。[作者的 X 串文](https://x.com/OskSta/status/1448248658865049605)和[可读展开版](https://threadreaderapp.com/thread/1448248658865049605.html)。
- 玻璃和石材环境光使用 Poly Haven 的 [Kloofendal 48d Partly Cloudy (Pure Sky)](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky)，校园几何和三个摄影机位由本项目制作。[HDRI 资产许可](https://polyhaven.com/license)。

## 重建

### 雨夜连廊

用户提供的深夜洗衣房画面作为明暗、材质与镜头尺度的标准。根据[ハヤシモン本人关于此作品的制作记录](https://x.com/hayashimon1/status/2108913484805406859)，先确定人眼高度的空间和构图，再做器物、印刷品、玻璃反光与表面磨损。场景延续致理楼 C 座的校园语境。连廊布局、饮水点、陈设和夜间色温均为游戏创作，室内无现场测绘依据。

用 Python 和 Pillow 执行 `corridor_prints.py <输出目录>/prints`，生成四张原创印刷品。在 Blender 5.1 的新进程中执行 `rain_corridor.py -- <输出目录>`，保存含六组可编辑构件、摄影机和内嵌印刷品的工程。用 Blender 打开该工程并执行 `render_corridor.py -- <输出目录> final`。Cycles 输出入口、公告栏两张透视图，以及三个 4096 × 2048 的球面全景。`corridor_atlas.py <输出目录> <本脚本所在目录>` 将全景转换为移动端使用的 WebP 立方体贴图，需要 NumPy 和 Pillow。每步对应独立的相机位置，三个位置可以环看，上述素材都随试玩页离线保存。

### 致理楼外景

使用 Blender 5.1 运行 `model.py`，在 `--` 后传入 GLB 输出目录。需要含中日韩字形的字体，构建脚本会将楼名转为网格。调用 `zhili.build(output_dir, studio=True)` 还会保存包含相机与内嵌材质的 Blender 工程。加载该工程运行 `render_views.py -- proof` 快速核对画面，省略 `-- proof` 时输出四张成片。将 C-court、C-entry、C-shelter 和 C-evening 依次转为本目录的 `arrival.webp`、`front.webp`、`shelter.webp` 和 `evening.webp`。运行 `export.cjs` 压缩几何并生成独立试玩页。

### 从自行车架走进庭院

把本目录加入 Blender Python 的 `sys.path`，在上一步生成的致理楼工程中运行 `groups = zhili_street.build()`。返回的集合包含通勤自行车、铺地、导向牌、展柜与远景。用 `zhili_street.export(groups, output_dir / "Street.glb")` 导出街景图层。对刚生成的建筑 GLB 执行一次 `zhili_street_leaves.refine_glb(base_dir / "Zhili.glb", output_dir / "Zhili.glb")`，同步入口绿篱。保存工程，选用 `05 | Campus cycle lane` 摄影机渲染首页的 `street.webp`。`export.cjs` 一起读取 `Yuehai.glb`、`Zhili.glb` 和 `Street.glb`。街面试玩从 `#walk/street` 进入，B 座台阶可从 `#walk/steps` 直接进入。

自行车停放的依据是[设计院庭院实拍](https://suiadr.com/u_file/fileUpload/2021-05/10/2021051064218.jpg)中左侧柱边的车轮，通道宽度和台阶前的铺地另据骑行者经过 B 座的现场照片。入口柱牌参照[心理学院的入口照片](https://psy.szu.edu.cn/en/images/ba1d0f55f4c605d9ad5a93fcd850442.jpg)。三辆车的车型、配色和停车架，以及导向牌、展柜、座椅和地下检修件为游戏陈设。展柜图版由项目绘制，楼层用途参照[深大信息中心](https://it.szu.edu.cn/zzjg/xxfwb.htm)。

街面镜头的远景树列和低层楼仅供环境衬景，位置按庭院视线推定。Blender 摄影机和游戏版本复用自行车及建筑几何。游戏另用五块有米制 UV 的草坪和曲面短草降低绘制成本，街景压缩保留浮点坐标，以免车轮辐条和展柜玻璃在缩放时重叠。柱廊地面采用模型烘焙的照度图。修改建筑后，在 Blender 中用 `zhili_court_shade.bake(scene, script_dir / "court-shade.png")` 重新计算，再打包网页。
