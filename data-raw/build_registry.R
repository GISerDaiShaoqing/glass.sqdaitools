# 一次性构建期脚本:由 archive_scan.csv + 样例核验结果,构建包内数据集 glass_products
# 前置:先运行 crawl_archive.R 与 verify_bands.R
# 运行: Rscript data-raw/build_registry.R
library(httr2)
library(rvest)
library(dplyr)
library(tibble)

base_url <- "https://glass.hku.hk/archive/"
UA <- "glass.sqdaitools-build/0.1 (R; contact dsq1993qingge@163.com)"

fetch_hrefs_dirs <- function(url) {
  tryCatch(
    request(url) |>
      req_user_agent(UA) |>
      req_timeout(30) |>
      req_perform() |>
      resp_body_string() |>
      (\(t) read_html(t) |> html_elements("a") |> html_attr("href"))(),
    error = function(e) character(0)
  )
}

# ---------- 1. 产品目录 → 中文名 ----------
long_names <- c(
  AGB = "Global Forest Aboveground Biomass (AGB)",
  Albedo = "Broadband Albedo (Albedo)",
  AWGF_LST = "All-Weather/Gap-free Land Surface Temperature (AWGF LST)",
  BBE = "Broadband Emissivity (BBE)",
  Crops = "Paddy Rice Mapping Products (Crops)",
  DSR = "Downward Shortwave Radiation (DSR)",
  EDD = "Erythemal Ultraviolet Radiation Daily Dose (EDD)",
  ET = "Evapotranspiration (ET)",
  EVI = "Enhanced Vegetation Index (EVI)",
  FAPAR = "Fraction of Absorbed Photosynthetically Active Radiation (FAPAR)",
  FFC = "Fractional Forest Cover (FFC)",
  FVC = "Fractional Vegetation Coverage (FVC)",
  GPP = "Gross Primary Production (GPP)",
  KGClim = "Koppen-Geiger Climate Classification (KGClim)",
  LAI = "Leaf Area Index (LAI)",
  LST = "Land Surface Temperature (LST)",
  LWRT = "Surface Long-Wave Radiation (LWR)",
  NDVI = "Normalized Difference Vegetation Index (NDVI)",
  NPP = "Net Primary Production (NPP)",
  PAR = "Photosynthetically Active Radiation (PAR)",
  RN = "All-Wave Net Radiation (NR)",
  SH = "Sensible Heat Flux (SH)",
  SM = "Soil Moisture (SM)",
  SRF = "Snow-free Blue-sky Land Surface Albedo Climatology",
  Ta = "Land Surface Air Temperature (Ta)",
  Tsa = "Land Surface-Air Temperature Difference (Tsa)",
  TPSCE = "Snow Cover Extent over the Tibetan Plateau (TPSCE)"
)

clean_dir <- function(x) sub("/$", "", x)

# ---------- 2. 扫描结果 → 归档变体骨架 ----------
scan <- read.csv("data-raw/archive_scan.csv", stringsAsFactors = FALSE)
# 统一剥掉目录名尾斜杠,避免 variant_id 带斜杠
scan$product <- clean_dir(scan$product)
scan$level1 <- clean_dir(scan$level1)
scan$level2 <- clean_dir(scan$level2)
scan <- scan[!is.na(scan$level1), ]

variants <- list()
for (pr in unique(scan$product)) {
  d1 <- scan[scan$product == pr & !is.na(scan$level1), c("level1", "level2")]
  for (src1 in unique(d1$level1)) {
    d2 <- d1[d1$level1 == src1, "level2"]
    lv2 <- d2[!is.na(d2)]
    src <- clean_dir(src1)
    if (length(lv2) == 0) {
      url_root <- paste0(base_url, pr, "/", src, "/")
      variants[[length(variants) + 1]] <- tibble(
        product = pr, source = src, res = NA_character_,
        layout = "flat", observed_years = NA_character_, url_root = url_root
      )
      next
    }
    yrs <- clean_dir(lv2)
    is_y <- grepl("^[0-9]{4}$", yrs)
    reses <- yrs[!is_y]
    yrs_seen <- yrs[is_y]
    if (length(reses) == 0) {
      url_root <- paste0(base_url, pr, "/", src, "/")
      variants[[length(variants) + 1]] <- tibble(
        product = pr, source = src, res = NA_character_,
        layout = "year_doy",
        observed_years = if (length(yrs_seen)) paste(range(yrs_seen), collapse = "-") else NA_character_,
        url_root = url_root
      )
      next
    }
    url_root_no_res <- paste0(base_url, pr, "/", src, "/")
    for (rso in reses) {
      variants[[length(variants) + 1]] <- tibble(
        product = pr, source = src, res = rso,
        layout = "year_doy",
        observed_years = NA_character_,
        url_root = paste0(url_root_no_res, rso, "/")
      )
    }
    if (length(yrs_seen) > 0) {
      variants[[length(variants) + 1]] <- tibble(
        product = pr, source = src, res = NA_character_,
        layout = "year_doy",
        observed_years = paste(range(yrs_seen), collapse = "-"),
        url_root = url_root_no_res
      )
    }
  }
}

derived <- bind_rows(variants) |>
  mutate(
    variant_id = ifelse(is.na(res),
                        paste0(product, "_", source),
                        paste0(product, "_", source, "_", gsub("\\.", "_", res)))
  ) |>
  distinct(variant_id, .keep_all = TRUE)

# ---------- 3. 对重点变体补探年份覆盖 ----------
probe_years <- function(url_root) {
  d <- fetch_hrefs_dirs(url_root)
  y <- clean_dir(d)
  y <- grep("^[0-9]{4}$", y, value = TRUE)
  if (length(y)) paste(range(as.integer(y)), collapse = "-") else NA_character_
}
for (vid in c("LAI_MODIS_250M", "NDVI_MODIS_250M", "EVI_MODIS_250M", "FVC_MODIS_500M")) {
  r <- derived[derived$variant_id == vid, ]
  y <- probe_years(r$url_root)
  cat("补探", vid, "->", y, "\n")
  Sys.sleep(0.4)
  derived$observed_years[derived$variant_id == vid] <- y
}

# ---------- 4. 样例核验层(LAI/NDVI/EVI/FVC/Ta 硬编码种子 + verify_batch.R 批量结果) ----------
overlay <- tibble(
  variant_id = c("LAI_MODIS_250M", "NDVI_MODIS_250M", "EVI_MODIS_250M",
                 "FVC_MODIS_500M", "Ta_MODIS"),
  version = c("V60", "V10", "V10", "V40", "V10"),
  code = c("GLASS01D01", "GLASS13D01", "GLASS14D01", "GLASS10E01", "GLASS18A01"),
  layer = c("LAI", "NDVI", "EVI", NA, NA),
  cadence_days = c(8L, 8L, 8L, 8L, 1L),
  temporal_res = c("8 days", "8 days", "8 days", "8 days", "daily"),
  fill_value = c(255, 255, 255, NA, NA),
  scale_factor = c(0.1, 0.01, 0.01, NA, NA),
  valid_min = c(0, -0.2, -0.1, NA, NA),
  valid_max = c(10, 1, 1, NA, NA),
  verified = TRUE
)
# 批量核验叠加(verify_batch.R 产出);同 variant_id 时 CSV 行优先于种子
overlay_csv <- "data-raw/verified_overlay.csv"
if (file.exists(overlay_csv)) {
  extra <- read.csv(overlay_csv, stringsAsFactors = FALSE)
  extra$cadence_days <- as.integer(extra$cadence_days)
  cat("叠加批量核验:", nrow(extra), "行 ->", overlay_csv, "\n")
  overlay <- bind_rows(extra, overlay[!overlay$variant_id %in% extra$variant_id, ])
}

glass_products <- derived
glass_products$long_name <- long_names[glass_products$product]
# 只补缺失列,不整体重建(保留 archive 扫描/补探得到的 observed_years 等)
for (cn in setdiff(names(overlay), c("variant_id", names(glass_products)))) {
  glass_products[[cn]] <- NA
}
idx <- match(overlay$variant_id, glass_products$variant_id)
iok <- which(!is.na(idx))
# 逐值回填;overlay 里为 NA 的格子不覆盖已有值
for (cn in setdiff(names(overlay), "variant_id")) {
  v <- overlay[[cn]][iok]
  has <- !is.na(v)
  if (any(has)) glass_products[[cn]][idx[iok][has]] <- v[has]
}
glass_products$verified[is.na(glass_products$verified)] <- FALSE
glass_products$notes[is.na(glass_products$notes)] <- ifelse(
  glass_products$verified[is.na(glass_products$notes)],
  "verified against a sample granule (naming, fill/scale bands metadata)",
  "skeleton from an archive directory scan; year coverage and band metadata not verified"
)

final_cols <- c("product", "long_name", "variant_id", "source", "res", "layout",
                "observed_years", "start_year", "end_year", "cadence_days",
                "temporal_res", "version", "code", "layer",
                "fill_value", "scale_factor", "valid_min", "valid_max",
                "verified", "url_root", "notes")

lastrow <- function(obs) {
  if (is.na(obs)) return(c(NA_real_, NA_real_))
  as.numeric(strsplit(obs, "-")[[1]])
}
sy <- do.call(rbind, lapply(glass_products$observed_years, lastrow))
stopifnot(ncol(sy) == 2)
glass_products$start_year <- sy[, 1]
glass_products$end_year   <- sy[, 2]

glass_products <- glass_products[, final_cols]
stopifnot(!any(is.na(glass_products$variant_id)), nrow(glass_products) > 50)

usethis::use_data(glass_products, overwrite = TRUE, version = 3)
cat("data/glass_products.rda OK:", nrow(glass_products), "variants\n")
