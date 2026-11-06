# 一次性构建期脚本:下载 3 个样例 HDF(h28v05, 2018-DOY217)+ xml 副驾,核验 band 元数据
# 输出:data-raw/band_meta.csv(+ 控制台详情);样本留 data-raw/samples/
library(httr2)
library(rvest)
library(dplyr)
library(tibble)

dir.create("data-raw/samples", showWarnings = FALSE)
UA <- "glass.sqdaitools-build/0.1 (R; contact dsq1993qingge@163.com)"

dirurl_for <- function(product) {
  sprintf("https://glass.hku.hk/archive/%s/MODIS/250M/2018/217/", product)
}

fetch_hrefs <- function(url) {
  request(url) |> req_user_agent(UA) |> req_timeout(30) |>
    req_perform() |> resp_body_string() |>
    (\(t) read_html(t) |> html_elements("a") |> html_attr("href"))()
}

dl <- function(url, dest, timeout_ = 240) {
  if (file.exists(dest) && file.size(dest) > 1000) {
    cat("  已存在:", dest, "\n"); return(invisible())
  }
  cat("  下载:", url, "\n")
  request(url) |> req_user_agent(UA) |> req_timeout(timeout_) |>
    req_perform(path = dest)
}

rows <- list()
for (product in c("LAI", "NDVI", "EVI")) {
  du <- dirurl_for(product)
  listing <- fetch_hrefs(du)
  hdf <- grep("h28v05[0-9.]*\\.hdf$", listing, value = TRUE)
  xml <- grep("h28v05[0-9.]*\\.hdf\\.xml$", listing, value = TRUE)
  cat("==", product, "== 精确文件名:", hdf, "|\n")
  if (length(hdf) == 0) { message("  未找到!"); next }
  dest_hdf <- file.path("data-raw/samples", hdf[1])
  dl(paste0(du, hdf[1]), dest_hdf)
  cat("  HDF 大小:", file.size(dest_hdf), "bytes\n")
  if (length(xml) >= 1) {
    dest_xml <- file.path("data-raw/samples", xml[1])
    dl(paste0(du, xml[1]), dest_xml)
    xml_hits <- tryCatch(
      grep("(?i)fillvalue|scale|slope|add_offset|valid_range|slope",
           readLines(dest_xml), value = TRUE),
      error = function(e) character(0))
    cat("  XML 元数据线索:", paste(head(xml_hits, 12), collapse = "\n"), "\n")
  }

  r <- terra::rast(dest_hdf)
  cat("  变量:", paste(names(r), collapse = ", "), "\n")
  print(t(terra::minmax(r)))
  evi12 <- NULL
  md <- tryCatch(
    {
      mdx <- terra:::gdalinfo(dest_hdf)
      paste(mdx, collapse = "\n")
    },
    error = function(e) paste0("<gdalinfo 不可用: ", conditionMessage(e), ">"))
  cat("  GDAL 元数据节选:\n")
  cat(head(grep("(?i)fill|scale|offset|band|type|range", unlist(strsplit(md, "\n")),
                value = TRUE), 20), sep = "\n")
  cat("\n")

  rows[[length(rows) + 1]] <- tibble(
    product = product, file = basename(dest_hdf),
    var_names = paste(names(r), collapse = ";"),
    minmax = paste(terra::minmax(r), collapse = ","),
    xml_meta = paste(xml_hits, collapse = " || "),
    gdal_meta = md
  )
  Sys.sleep(0.5)
}

out <- bind_rows(rows)
readr::write_csv(out, "data-raw/band_meta.csv")
cat("已写入 data-raw/band_meta.csv\n")
