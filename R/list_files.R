#' List files of a GLASS archive composite folder
#'
#' @description
#' Reads the GLASS archive directory listing for one composite folder and
#' returns the matching data files as a manifest (filename, URL, doy, tile).
#' The listing is plain HTML with relative links, so no credentials or API
#' keys are needed.
#'
#' @param variant_id Registry variant key, e.g. `"LAI_MODIS_250M"`.
#' @param year Calendar year of the composite (folder level). May be `NULL`
#'   for "flat" layout variants (e.g. AGB).
#' @param doy Day of year of the composite, integer or `"217"`; `NULL` only
#'   allowed for "flat" variants.
#' @param tiles Optional tile selector: a character vector like
#'   `c("h28v05")` or a data frame with `h`/`v` columns (e.g. the output of
#'   [glass_tiles_for_bbox()]).
#' @param ext File extensions to keep, e.g. `c("hdf", "hdf.xml")`;
#'   default `"hdf"` (the data files).
#' @return A tibble with columns `filename`, `url`, `variant_id`, `year`,
#'   `doy`, `tile`, `ext`.
#'
#' @export
#' @examples
#' \dontrun{
#' glass_list_files("LAI_MODIS_250M", year = 2018, doy = 217, tiles = "h28v05")
#' }
glass_list_files <- function(variant_id, year = NULL, doy = NULL,
                             tiles = NULL, ext = "hdf") {
  info <- glass_product_info(variant_id = variant_id)
  tile_ids <- .glass_tile_ids(tiles)
  layout <- info$layout[[1]]

  if (layout == "year_doy") {
    if (is.null(year)) glass_abort("This variant requires `year`")
    if (is.null(doy)) glass_abort("This variant requires `doy` (a composite day of year)")
    url_folder <- paste0(info$url_root[[1]], year, "/", sprintf("%03d", as.integer(doy)), "/")
  } else if (layout == "flat") {
    url_folder <- info$url_root[[1]]
  } else {
    glass_abort(paste0("Unknown layout '", layout, "'"))
  }

  refs <- .glass_fetch_hrefs_safe(url_folder)
  files <- refs[!endsWith(refs, "/")]
  if (length(files) == 0L) {
    return(.glass_list_files_empty(variant_id))
  }

  ext_pat <- paste0("(", paste(
    vapply(ext, function(e) paste0("\\.", gsub("\\.", "\\\\.", e), "$"), character(1)),
    collapse = "|"), ")")
  sel <- grepl(ext_pat, files, ignore.case = TRUE)
  if (!is.null(tile_ids)) {
    sel <- sel & grepl(paste0("(", paste(tile_ids, collapse = "|"), ")"), files)
  }
  # 已核验的产品要求文件名含 GLASS 代码,排除误置文件
  if (isTRUE(info$verified[[1]]) && !is.na(info$code[[1]])) {
    sel <- sel & startsWith(files, info$code[[1]])
  }
  files <- files[sel]
  if (length(files) == 0L) {
    message("no matching files under ", url_folder)
    return(.glass_list_files_empty(variant_id))
  }

  exts <- tools::file_ext(files)
  exts[endsWith(files, ".hdf.xml")] <- "hdf.xml"
  year_col <- if (is.null(year)) rep(NA_integer_, length(files)) else rep(as.integer(year), length(files))
  doy_col <- if (is.null(doy)) rep(NA_integer_, length(files)) else rep(as.integer(doy), length(files))
  tibble::tibble(
    filename = files,
    url = paste0(url_folder, files),
    variant_id = rep(variant_id, length(files)),
    year = year_col,
    doy = doy_col,
    tile = regmatches(files, regexpr("h[0-9]{2}v[0-9]{2}", files)),
    ext = exts
  )
}

.glass_list_files_empty <- function(variant_id) {
  tibble::tibble(
    filename = character(),
    url = character(),
    variant_id = rep(variant_id, 0L),
    year = integer(),
    doy = integer(),
    tile = character(),
    ext = character()
  )
}

.glass_fetch_hrefs_safe <- function(url) {
  tryCatch(
    .glass_fetch_hrefs(url),
    error = function(e) {
      message("listing failed for ", url, ": ", conditionMessage(e))
      character(0)
    }
  )
}
