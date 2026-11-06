# 一次性构建期脚本:扫描 glass.hku.hk/archive/ 的目录结构
# 输出 data-raw/archive_scan.csv(供 build_registry.R 整理成 glass_products 数据集)
# 手动运行: Rscript data-raw/crawl_archive.R
library(httr2)
library(rvest)
library(dplyr)
library(tibble)

UA <- "glass.sqdaitools-build/0.1 (R; contact dsq1993qingge@163.com)"

parse_links <- function(url) {
  html <- request(url) |>
    req_user_agent(UA) |>
    req_timeout(30) |>
    req_perform() |>
    resp_body_string()
  hrefs <- read_html(html) |> html_elements("a") |> html_attr("href")
  # 目录
  dirs <- grep("/$", hrefs, value = TRUE)
  dirs[!dirs %in% c("../", "/")]
}

fetch <- function(url) tryCatch(parse_links(url), error = function(e) character(0))

base <- "https://glass.hku.hk/archive/"
cat("扫描产品目录 ...\n")
products <- sort(fetch(base))

rows <- list()
i <- 0
for (p in products) {
  purl <- paste0(base, p)
  Sys.sleep(0.3)
  level1 <- fetch(purl)
  cat(sprintf("  %s (%d 个一级子目录)\n", sub("/$", "", p), length(level1)))
  rows[[length(rows) + 1]] <- tibble(
    product = p, level1 = NA, level2 = NA, url = purl
  )
  for (s1 in level1) {
    url1 <- paste0(purl, s1)
    Sys.sleep(0.3)
    level2 <- fetch(url1)
    i <- i + 1  # 只有这里发生真实请求
    cat(sprintf("    %s (%d 个二级子目录)\n", sub("/$", "", s1), length(level2)))
    rows[[length(rows) + 1]] <- tibble(
      product = p, level1 = s1, level2 = NA, url = url1
    )
    for (s2 in level2) {
      rows[[length(rows) + 1]] <- tibble(
        product = p, level1 = s1, level2 = s2, url = paste0(url1, s2)
      )
    }
  }
}

scan <- bind_rows(rows)
readr::write_csv(scan, "data-raw/archive_scan.csv")
cat("已写入 data-raw/archive_scan.csv,共", nrow(scan), "行;请求数:", i, "\n")
