# 快速上手 glass.sqdaitools(中文)

``` r
library(glass.sqdaitools)
```

本教程走一遍 `glass.sqdaitools` 覆盖的 GLASS 数据全流程:产品登记表查询、
研究区到瓦片的映射、日期到合成 DOY 的换算、批量下载与后处理。
与数据集相关的代码块可离线运行;凡涉及网络的代码块均以 `eval = FALSE`
展示,保证本教程在无网环境也能构建。 英文版请见 `glass-quickstart`。

## 产品登记表

登记表对 GLASS 归档(<https://glass.hku.hk/archive/>)中的每个
“归档变体”(产品 × 数据源 × 分辨率)记录一行:

``` r
glass_registry(verified_only = TRUE)[, c("variant_id", "res", "cadence_days",
                                         "observed_years", "url_root")]
#>          variant_id  res cadence_days observed_years
#> 42   EVI_MODIS_250M 250M            8      2000-2025
#> 58   FVC_MODIS_500M 500M            8      2000-2024
#> 106  LAI_MODIS_250M 250M            8      2000-2025
#> 119 NDVI_MODIS_250M 250M            8      2000-2025
#> 131        Ta_MODIS <NA>            1      2000-2020
#>                                          url_root
#> 42   https://glass.hku.hk/archive/EVI/MODIS/250M/
#> 58   https://glass.hku.hk/archive/FVC/MODIS/500M/
#> 106  https://glass.hku.hk/archive/LAI/MODIS/250M/
#> 119 https://glass.hku.hk/archive/NDVI/MODIS/250M/
#> 131        https://glass.hku.hk/archive/Ta/MODIS/
```

`verified = TRUE` 的变体经过真实样例 granule 核验:文件命名片段
(`code`、`version`、`layer`)、年份覆盖,以及波段元数据
(`fill_value`、`scale_factor`、`valid_min/valid_max`)—— 后者会被
[`glass_read()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_read.md)
/
[`glass_process()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_process.md)
直接使用。

按产品目录查看简表:

``` r
glass_registry() |>
  dplyr::group_by(product) |>
  dplyr::summarise(
    long_name  = dplyr::first(long_name),
    n_variants = dplyr::n(),
    .groups = "drop"
  )
#> # A tibble: 27 × 3
#>    product  long_name                                                 n_variants
#>    <chr>    <chr>                                                          <int>
#>  1 AGB      Global Forest Aboveground Biomass (AGB)                            4
#>  2 AWGF_LST All-Weather/Gap-free Land Surface Temperature (AWGF LST)           4
#>  3 Albedo   Broadband Albedo (Albedo)                                         10
#>  4 BBE      Broadband Emissivity (BBE)                                         7
#>  5 Crops    Paddy Rice Mapping Products (Crops)                                3
#>  6 DSR      Downward Shortwave Radiation (DSR)                                 4
#>  7 EDD      Erythemal Ultraviolet Radiation Daily Dose (EDD)                   1
#>  8 ET       Evapotranspiration (ET)                                            5
#>  9 EVI      Enhanced Vegetation Index (EVI)                                    4
#> 10 FAPAR    Fraction of Absorbed Photosynthetically Active Radiation…          8
#> # ℹ 17 more rows
```

## 研究区 → 瓦片

GLASS 分幅产品沿用 MODIS 正弦投影的 `h/v` 网格。函数会重建精确的
瓦片多边形,告诉你研究区落在哪些瓦片上:

``` r
# 上海人民广场周边 3 km 缓冲
roi <- sf::st_buffer(
  sf::st_sfc(sf::st_point(c(121.47, 31.23)), crs = 4326),
  3000
)
tiles <- glass_tiles_for_sf(roi)
tiles[, c("h", "v", "lon_min", "lon_max", "lat_min", "lat_max", "valid")]
#> Simple feature collection with 1 feature and 7 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 115.4701 ymin: 30 xmax: 143.5948 ymax: 40
#> Geodetic CRS:  WGS 84
#>    h v  lon_min  lon_max lat_min lat_max valid                       geometry
#> 1 28 5 115.4701 143.5948      30      40  TRUE POLYGON ((130.5407 40, 143....
```

给定的直接是经纬度外接矩形时,用
[`glass_tiles_for_bbox()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_tiles_for_bbox.md);
返回表(含 `h`/`v` 列)可以直接传给
[`glass_fetch()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_fetch.md)。

## 日期区间 → 合成 DOY 文件夹

归档按”合成起始日”的年积日(DOY)组织文件夹:

``` r
glass_doys("LAI_MODIS_250M", from = "2018-08-01", to = "2018-08-31")
#> # A tibble: 5 × 4
#>    year   doy date       folder
#>   <int> <int> <date>     <chr> 
#> 1  2018   209 2018-07-28 209   
#> 2  2018   217 2018-08-05 217   
#> 3  2018   225 2018-08-13 225   
#> 4  2018   233 2018-08-21 233   
#> 5  2018   241 2018-08-29 241
```

默认 `mode = "span"` 保留与日期区间**有交集**的所有合成;
`mode = "start"` 只保留起始日落入区间内的合成——即旧脚本常用的语义。

## 检索与下载文件

[`glass_list_files()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_list_files.md)
读取单个合成文件夹的目录清单;
[`glass_fetch()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_fetch.md)
按上一步的 DOY 表循环检索并下载(支持断点续传与校验):

``` r
files <- glass_fetch(
  "LAI_MODIS_250M",
  from = "2018-08-01", to = "2018-12-31",
  roi = roi,
  out_dir = "data/glass/lai"
)
# 先看清单不下载:dry_run = TRUE
```

下载引擎会与服务器比对文件大小,通过 HTTP `Range` 续传 `.part`
半截文件,并把 `glass_manifest.csv` 台账写进 `out_dir`,
中断后重跑会自动接着上次的进度。

## 后处理

[`glass_process()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_process.md)
是参数化后的完整流水线:清理 → 镶嵌 → 重投影 → 掩膜 → 可选的时间维折叠:

``` r
mean_lai <- glass_process(
  files,
  roi = roi,
  product = "LAI_MODIS_250M",
  method = "cubic",
  fun = "mean",
  outfile = "glass_lai_mean.tif"
)
```

波段清理规则来自登记表:原始填充值(如 255)按比例因子换算后置为
`NA`,有效范围之外的值同样剔除。若输入是已读入的 `SpatRaster`,
[`glass_read()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_read.md)
只应用显式传入的 `fill`/`valid_range` 参数。

## 交互式下载界面

``` r
glass_app()
```

在地图上点击两次框出研究区矩形,选择已核验的产品变体与日期区间,
预览清单后一键下载——底层复用的都是上述包函数。 底图默认为无偏移的 Esri
影像;可选高德街道图层,注意其为 GCJ-02 坐标(与 WGS84 存在约 500 米偏移)。
