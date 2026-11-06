# 一次性构建期脚本:抽样各产品的 DOY 目录,记录文件命名规律
# 输出 data-raw/sample_listings.csv
library(httr2)
library(rvest)
library(tibble)

UA <- "glass.sqdaitools-build/0.1 (R; contact dsq1993qingge@163.com)"

fetch_files <- function(url) {
  html <- request(url) |>
    req_user_agent(UA) |>
    req_timeout(30) |>
    req_perform() |>
    resp_body_string()
  hrefs <- read_html(html) |> html_elements("a") |> html_attr("href")
  hrefs[!hrefs %in% c("../", "/")]
}

# 探测点:产品/源/分辨率/年/DOY(结合 archive_scan 的已知结构挑选)
probes <- list(
  list(product = "LAI", src = "MODIS", res = "250M", year = 2018, doy = "217"),
  list(product = "NDVI", src = "MODIS", res = "250M", year = 2018, doy = "217"),
  list(product = "EVI", src = "MODIS", res = "250M", year = 2018, doy = "217"),
  list(product = "FVC", src = "MODIS", res = "500M", year = 2018, doy = "217"),
  list(product = "Ta", src = "MODIS", year = 2018, doy = "217")
)

rows <- list()
for (pr in probes) {
  if (is.null(pr$res)) {
    url <- sprintf("https://glass.hku.hk/archive/%s/%s/%s/%s/",
                   pr$product, pr$src, pr$year, pr$doy)
  } else {
    url <- sprintf("https://glass.hku.hk/archive/%s/%s/%s/%s/%s/",
                   pr$product, pr$src, pr$res, pr$year, pr$doy)
  }
  cat("探测:", url, "\n")
  files <- tryCatch(fetch_files(url), error = function(e) {
    message("  失败: ", conditionMessage(e))
    character(0)
  })
  cat("  文件数:", length(files), " 前 6 个:\n")
  print(head(files, 6))
  rows[[length(rows) + 1]] <- tibble(
    product = pr$product, url = url, n_files = length(files),
    first_files = paste(head(files, 6), collapse = " | ")
  )
  Sys.sleep(0.5)
}

out <- dplyr::bind_rows(rows)
write.csv(out, "data-raw/sample_listings.csv", row.names = FALSE)
cat("已写入 data-raw/sample_listings.csv\n")
