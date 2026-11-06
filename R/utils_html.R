# 内部工具:httr2 请求与 HTML 目录解析

# 请求一个目录页并解析出全部 <a href>
.glass_fetch_hrefs <- function(url, timeout_s = 30) {
  resp <- httr2::request(url) |>
    httr2::req_user_agent(.glass_user_agent()) |>
    httr2::req_timeout(timeout_s) |>
    httr2::req_perform()
  status <- httr2::resp_status(resp)
  if (status %in% c(404L, 502L, 503L)) {
    glass_abort(sprintf("HTTP %s: %s", status, url))
  }
  body <- httr2::resp_body_string(resp)
  doc <- rvest::read_html(body)
  refs <- rvest::html_attr(rvest::html_elements(doc, "a"), "href")
  refs[!is.na(refs)]
}

.glass_user_agent <- function() {
  "glass.sqdaitools/0.1 (R; +https://github.com/GISerDaiShaoqing/glass.sqdaitools)"
}

# tiles 参数规整:支持 "h28v05" 字符向量,或带 h/v 列的数据框/(sf)
.glass_tile_ids <- function(tiles) {
  if (is.null(tiles)) return(NULL)
  if (is.character(tiles)) {
    return(unlist(strsplit(tiles, ",", fixed = FALSE), use.names = FALSE))
  }
  if (is.data.frame(tiles) && all(c("h", "v") %in% names(tiles))) {
    return(sprintf("h%02dv%02d", tiles$h, tiles$v))
  }
  glass_abort("`tiles` must be a character vector or a data frame with h/v columns")
}
