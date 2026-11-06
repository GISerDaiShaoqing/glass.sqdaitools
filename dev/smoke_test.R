# 开发冒烟脚本(合并各测试散件)
# 用法:
#   离线部分: Rscript dev/smoke_test.R
#   联网部分: 先设 GLASS_SMOKE=1 再运行(会下载少量样例文件)
devtools::load_all()

cat("\n== 1) 离线:查询层 ==\n")
stopifnot("LAI_MODIS_250M" %in% glass_registry("LAI")$variant_id)
stopifnot(glass_product_info(variant_id = "LAI_MODIS_250M")$fill_value == 255)

t <- glass_tiles_for_bbox(120.8, 30.6, 122.2, 31.9)
stopifnot("h28v05" %in% sprintf("h%02dv%02d", t$h, t$v))

d <- glass_doys("LAI_MODIS_250M", "2018-08-01", "2018-12-31", mode = "start")
stopifnot(identical(d$folder, sprintf("%03d", seq(217, 361, 8))))
cat("离线冒烟 OK\n")

smoke <- identical(Sys.getenv("GLASS_SMOKE", "0"), "1")

cat("\n== 2) 网络与端到端(GLASS_SMOKE=1 才跑) ==\n")
if (!smoke) {
  cat("跳过(未设 GLASS_SMOKE)\n")
} else {
  out_dir <- file.path(tempdir(), "glass_smoke_ndvi")
  dir.create(out_dir, showWarnings = FALSE)
  res <- glass_fetch("NDVI_MODIS_250M",
                     from = "2018-08-01", to = "2018-08-31",
                     tiles = c("h28v05"), doys_mode = "start",
                     out_dir = out_dir, delay = 0.5)
  print(table(res$status))
  stopifnot(all(res$status %in% c("downloaded", "skipped")))

  # 幂等重跑
  res2 <- glass_fetch("NDVI_MODIS_250M",
                      from = "2018-08-01", to = "2018-08-31",
                      tiles = c("h28v05"), doys_mode = "start",
                      out_dir = out_dir, delay = 0.2, quiet = TRUE)
  stopifnot(all(res2$status == "skipped"))
  cat("幂等重跑 OK\n")

  sh <- sf::st_sfc(sf::st_point(c(121.47, 31.23)), crs = 4326) |>
    sf::st_buffer(8000) |>
    sf::st_transform("+proj=utm +zone=51 +datum=WGS84 +units=m +no_defs")
  tf <- file.path(out_dir, "ndvi_mean_utm51.tif")
  r_mean <- glass_process(res2$destfile, roi = sh,
                          product = "NDVI_MODIS_250M",
                          fun = "mean", outfile = tf)
  stopifnot(file.exists(tf))
  # NDVI 有效范围 [-0.2, 1](含水体负值)
  gv <- terra::global(r_mean, c("min", "max"), na.rm = TRUE)
  stopifnot(gv$min >= -0.2, gv$max <= 1)
  cat("后处理合成 OK: tif =", tf, "\n")
}
cat("\n冒烟测试全部通过\n")
