# 一次性构建期脚本:把 glass_tiles.tsv 转成包内数据集 glass_tiles
# 运行: Rscript data-raw/build_tiles.R
library(tibble)
library(dplyr)

tiles <- read.table("data-raw/glass_tiles.tsv", header = TRUE)

# 行数校验:18 v 档 × 36 h 档 = 648
stopifnot(nrow(tiles) == 18 * 36)
# 有效行(投影覆盖内)应为 460
stopifnot(sum(tiles$lon_min > -900) == 460)

glass_tiles <- tiles |>
  as_tibble() |>
  # 列名规整:GLASS/MODIS 的通用叫法是 h(横), v(纵);tsv 原列名为 ih/iv
  rename(h = ih, v = iv) |>
  mutate(across(c(lon_min, lon_max, lat_min, lat_max), ~ ifelse(.x <= -900, NA_real_, .x)))
glass_tiles$valid <- !is.na(glass_tiles$lon_min)
glass_tiles <- glass_tiles[, c("h", "v", "lon_min", "lon_max", "lat_min", "lat_max", "valid")]

stopifnot(sum(glass_tiles$valid) == 460)

usethis::use_data(glass_tiles, overwrite = TRUE, version = 3)
cat("data/glass_tiles.rda OK:", nrow(glass_tiles), "rows\n")
