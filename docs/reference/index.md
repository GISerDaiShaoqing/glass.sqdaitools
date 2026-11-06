# Package index

## 产品登记表 Registry

浏览 GLASS 归档变体、命名片段与波段元数据。 Browse archive variants,
naming fragments and band metadata.

- [`glass_registry()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_registry.md)
  [`glass_product_info()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_registry.md)
  : Query the GLASS product registry
- [`get_glass_product_table()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/get_glass_product_table.md)
  : Fetch the GLASS product overview table online

## 瓦片与时间 Tiles & DOY

研究区到 h/v 瓦片、日期区间到合成 DOY。 ROI-to-tile mapping and date
range to composite folders.

- [`glass_tiles_for_bbox()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_tiles_for_bbox.md)
  [`glass_tiles_for_sf()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_tiles_for_bbox.md)
  : Map a region of interest onto GLASS sinusoidal tiles
- [`glass_doys()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_doys.md)
  : Convert a date range to composite DOY folders

## 检索与下载 List & Download

目录清单与带断点续传的批量下载。 Folder listings and resumable batch
downloads.

- [`glass_list_files()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_list_files.md)
  : List files of a GLASS archive composite folder
- [`glass_download_file()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_download_file.md)
  : Download one GLASS file with resume support
- [`glass_download()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_download.md)
  : Batch download a GLASS file manifest
- [`glass_fetch()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_fetch.md)
  : Fetch GLASS granules for a variant, ROI and date range in one call

## 后处理 Post-processing

填充值/比例因子处理、镶嵌、重投影与时间合成。 Fill/scale handling,
mosaics, reprojection and composites.

- [`glass_read()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_read.md)
  : Read GLASS HDF granules with fill/scale handling
- [`glass_mosaic()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_mosaic.md)
  : Merge multi-tile GLASS rasters
- [`glass_process()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_process.md)
  : Reproject, mask and composite GLASS rasters for a region

## 交互界面 Interactive UI

- [`glass_app()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_app.md)
  : Launch the interactive GLASS download interface

## 内置数据集 Data

瓦片查找表与产品登记表。 Tile lookup table and product registry.

- [`glass_tiles`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_tiles.md)
  : GLASS sinusoidal tile lookup table
- [`glass_products`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_products.md)
  : GLASS product registry
