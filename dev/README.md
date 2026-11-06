# dev/ 目录说明(构建期开发资产,不随 R 包分发)

## 数据集构建链(一次性,按序在仓库根目录运行)

```bash
Rscript data-raw/crawl_archive.R    # 抓 glass.hku.hk/archive/ 目录树 -> archive_scan.csv
Rscript data-raw/probe_samples.R    # 抽样各产品 DOY 目录 -> sample_listings.csv
Rscript data-raw/verify_bands.R     # 下载 3 个样例 HDF + xml -> samples/ + band_meta.csv
Rscript data-raw/build_tiles.R      # glass_tiles.tsv -> data/glass_tiles.rda
Rscript data-raw/build_registry.R   # 全部以上 -> data/glass_products.rda
Rscript -e 'devtools::document()'   # man/ + NAMESPACE
```

需要联网;crawl/probe/verify 的样本与中间产物都在 data-raw/(样本目录已 gitignore)。

## 其余脚本

- `smoke_test.R`:离线查询层冒烟;设 `GLASS_SMOKE=1` 加跑网络端到端(下载 4 个
  NDVI granule + UTM51N mean 合成)。
- 备忘:本机 leafem 0.2.5 不含绘图类函数(addDrawToolbar/addPM* 为 Protomaps
  功能),Shiny 界面因此采用原地两点画框方案,不依赖第三方绘图插件。

## Ban 元数据核验结论(2026-06 存档于 band_meta.csv)

实测样例(h28v05,2018 DOY217):
- LAI(GLASS01D01 V6):terra/GDAL 读取时自动套用 scale=0.1;raw fill=255
  (读入后表现为 25.5);有效范围 [0, 10]
- NDVI/EVI(GLASS13D01/GLASS14D01 V1):scale=0.01;fill=255(读入后 2.55);
  有效范围 [-0.2, 1] / [-0.1, 1]
- 注意:`terra::freq()` 对小数层取整显示,判断值域请用 `global()`/`extract()`
