# 致理楼外景

入口以[深圳大学心理学院的 C 座照片](https://psy.szu.edu.cn/en/images/ba1d0f55f4c605d9ad5a93fcd850442.jpg)为依据。画面里最值得对齐的是低横梁的上下缘、深灰柱之间的留白、白色楼梯的折线，以及蓝色院牌相对楼梯的位置。

楼群轮廓参照[深大建筑设计研究院的教育项目](http://www.suiadr.com/project?dd=10#project-id-p-cate46)中「理工科教学楼、实验与信息中心」的[庭院斜视](http://www.suiadr.com/u_file/fileUpload/2021-05/10/2021051077344.jpg)和[塔楼正视](http://www.suiadr.com/u_file/fileUpload/2021-05/10/2021051064218.jpg)。白色塔冠内凹，后方教学翼带弧度，玻璃厅架在立柱上。模型按比例目测，背面、景观及夜间灯光是创作推定。参考照片链接到原发布方。

## 制作方法

- 从固定机位对齐大体块和负空间之后再开窗。参考 Ian Hubert 的[建筑建模演示](https://www.youtube.com/watch?v=v_ikG-u_6r0)。本场景给主要窗洞建了窗台和退进深度，曲面教学翼按弧线排布可复用的立面单元。
- Anastasia Opara 展示了植被如何适应墙面以及拱洞的边界。本场景用花池轮廓约束灌木和叶簇的分布。[作者的 X 串文](https://x.com/anastasiaopara/status/1543163341513842690)和[可读展开版](https://threadreaderapp.com/thread/1543163341513842690.html)。
- Oskar Stålberg 说明了地形表现和玩法格可以使用不同的网格。对应到栖灵，场景中三个可选活动点单独保存，弧形建筑、铺地和楼梯可以各按现场造型连续展开。[作者的 X 串文](https://x.com/OskSta/status/1448248658865049605)和[可读展开版](https://threadreaderapp.com/thread/1448248658865049605.html)。
- 玻璃和石材环境光使用 Poly Haven 的 [Kloofendal 48d Partly Cloudy (Pure Sky)](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky)，校园几何和三个摄影机位由本项目制作。[HDRI 资产许可](https://polyhaven.com/license)。

## 重建

### 雨夜连廊

用户提供的深夜洗衣房画面作为明暗、材质与镜头尺度的标准。根据[ハヤシモン本人关于此作品的制作记录](https://x.com/hayashimon1/status/2108913484805406859)，先确定人眼高度的空间和构图，再做器物、印刷品、玻璃反光与表面磨损。场景延续致理楼 C 座的校园语境。连廊布局、饮水点、陈设和夜间色温均为游戏创作，室内无现场测绘依据。

用 Python 和 Pillow 执行 `corridor_prints.py <输出目录>/prints`，生成四张原创印刷品。在 Blender 5.1 的新进程中执行 `rain_corridor.py -- <输出目录>`，保存含六组可编辑构件、摄影机和内嵌印刷品的工程。用 Blender 打开该工程并执行 `render_corridor.py -- <输出目录> final`。Cycles 输出入口、公告栏两张透视图，以及三个 4096 × 2048 的球面全景。`corridor_atlas.py <输出目录> <本脚本所在目录>` 将全景转换为移动端使用的 WebP 立方体贴图，需要 NumPy 和 Pillow。每步对应独立的相机位置，三个位置可以环看，上述素材都随试玩页离线保存。

### 致理楼外景

使用 Blender 5.1 运行 `model.py`，在 `--` 后传入 GLB 输出目录。需要含中日韩字形的字体，构建脚本会将楼名转为网格。调用 `zhili.build(output_dir, studio=True)` 还会保存包含相机和材质节点的 Blender 工程。在该工程上运行 `render_views.py` 得到三幅图片。将入口和傍晚两张转换成 `front.webp` 及 `evening.webp`，放在本目录。随后用 `export.cjs` 压缩几何并生成独立的试玩页。
