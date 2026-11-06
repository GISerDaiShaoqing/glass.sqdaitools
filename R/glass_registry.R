#' Query the GLASS product registry
#'
#' @description
#' `glass_registry()` returns the bundled [glass_products] registry, optionally
#' filtered. `glass_product_info()` returns one or a few rows and errors
#' loudly when the lookup is ambiguous, so it is handy for interactive use.
#'
#' @param product Product directory name(s) under /archive/, e.g. `"LAI"`.
#'   In `glass_registry()`, `NULL` keeps all products.
#' @param variant_id Optional exact variant key(s), e.g. `"LAI_MODIS_250M"`.
#' @param verified_only If `TRUE`, return only variants whose file naming and
#'   band metadata were verified against a sample granule.
#'
#' @return A tibble of registry rows (see [glass_products] for columns).
#'
#' @export
#' @examples
#' glass_registry("LAI")
#' glass_product_info("NDVI_MODIS_250M")
glass_registry <- function(product = NULL, variant_id = NULL, verified_only = FALSE) {
  tab <- glass_products
  if (verified_only) tab <- tab[tab$verified, , drop = FALSE]
  if (!is.null(product)) tab <- tab[tab$product %in% product, , drop = FALSE]
  if (!is.null(variant_id)) tab <- tab[tab$variant_id %in% variant_id, , drop = FALSE]
  tab
}

#' @rdname glass_registry
#' @export
glass_product_info <- function(variant_id = NULL, product = NULL) {
  if (is.null(variant_id) && is.null(product)) {
    glass_abort("`variant_id` or `product` must be provided")
  }
  sel <- seq_len(nrow(glass_products))
  if (!is.null(variant_id)) sel <- sel[glass_products$variant_id %in% variant_id]
  if (!is.null(product)) sel <- sel[glass_products$product %in% product]
  if (length(sel) == 0) {
    glass_abort("No registry rows match the query")
  }
  glass_products[sel, , drop = FALSE]
}

# informative base-R error (avoid depending on rlang)
glass_abort <- function(msg) stop(msg, call. = FALSE)

#' Fetch the GLASS product overview table online
#'
#' Scrapes the product overview table from glass.hku.hk with 'httr2'. On
#' failure the bundled 25-product fallback table is used. In new code prefer
#' [glass_registry()]/[glass_product_info()], which also carry archive paths
#' and band metadata.
#'
#' @param use_fallback Logical; if `TRUE` (default) return the bundled
#'   fallback table when the online scrape fails.
#' @return A data frame of product overview rows, or `NULL`.
#'
#' @export
get_glass_product_table <- function(use_fallback = TRUE) {
  fallback_df <- tibble::tibble(
    no = 1:25,
    product = c(
      "Leaf Area Index (LAI)", "Broadband Albedo (Albedo)", "Broadband Emissivity (BBE)",
      "Photosynthetically Active Radiation (PAR)",
      "Fraction of Absorbed Photosynthetically Active Radiation (FAPAR)",
      "Downward Shortwave Radiation (DSR)", "Surface Long-Wave Radiation (LWR)",
      "All-Wave Net Radiation (NR)", "Sensible heat flux (SH)",
      "Land Surface Temperature (LST)",
      "Al-Weather/Gap-free Land Surface Temperature (Al-Weather/Gap-free LST)",
      "Land Surface Air Temperature (Ta)",
      "Land Surface-Air Temperature Difference (Tsa)",
      "Fractional Vegetation Coverage (FVC)", "Evapotranspiration (ET)",
      "Gross Primary Production (GPP)", "Net Primary Production (NPP)",
      "Global Forest Aboveground Biomass (AGB)",
      "Snow Cover Extent over the Tibetan Plateau (TPSCE)",
      "Snow-free Blue-sky Land Surface Albedo Climatology",
      "Normalized difference vegetation index (NDVI)",
      "Enhanced Vegetation Index (EVI)", "Soil moisture (SM)",
      "Fractional Forest Cover (FFC)",
      "Erythemal Ultraviolet Radiation Daily Dose (EDD)"
    ),
    temporal_range = c(
      "1981-2024", "1981-2024", "1981-2022", "2000-2024", "1981-2023",
      "2000-2024", "2000-2022", "1981-2024", "2000-2020", "1981-2022",
      "2011-2021", "2000-2020", "2000-2020", "1981-2024", "1981-2023",
      "1981-2024", "1981-2024", "1985-2015", "1982-2018", "1981-2022",
      "2000-2024", "2000-2024", "1982-2020", "2000-2024", "2005-2022"
    ),
    temporal_resolution = c(
      "8 days", "4 days / 8 days", "Daily", "Daily", "8 days",
      "Daily", "Instantaneous/8 days", "Daily", "Daily", "Instantaneous/Daily",
      "8 days", "Daily", "Daily", "8 days", "8 days",
      "8 days", "8 days", "5 years", "8 days", "8 days",
      "8 days", "8 days", "daily", "8 days", "Daily"
    ),
    spatial_resolution = c(
      "250m/500m/1km/0.05\u00b0", "250m/500m/1km/0.05\u00b0", "0.05\u00b0", "0.05\u00b0",
      "250m/500m/1km/0.05\u00b0", "0.05\u00b0", "1km/0.05\u00b0", "0.05\u00b0", "1km", "1km/0.05\u00b0",
      "2km/0.02\u00b0/0.05\u00b0", "1km", "1km", "500m/0.05\u00b0", "1km/0.05\u00b0",
      "500m/1km/0.05\u00b0", "500m/1km/0.05\u00b0", "0.05\u00b0", "0.05\u00b0", "500m/0.05\u00b0/0.5\u00b0",
      "250m/0.05\u00b0/0.1\u00b0/0.25\u00b0", "250m/0.05\u00b0/0.1\u00b0/0.25\u00b0", "0.05\u00b0/1km", "250m", "1KM"
    )
  )

  url <- "https://glass.hku.hk/overview.html"
  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_user_agent("glass.sqdaitools/0.1 (R; +glass.sqdaitools)") |>
      httr2::req_timeout(10) |>
      httr2::req_perform(),
    error = function(e) {
      message("download failed: ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(resp) || !httr2::resp_status(resp) %in% c(200L, 201L)) {
    if (use_fallback) {
      message("using bundled fallback table (25 products).")
      return(fallback_df)
    }
    return(NULL)
  }

  webpage <- rvest::read_html(httr2::resp_body_string(resp))
  tables <- rvest::html_table(webpage, fill = TRUE)
  if (length(tables) == 0) {
    message("no table found on the page.")
    return(NULL)
  }
  product_df <- tables[[1L]]
  product_df <- product_df[!apply(is.na(product_df) | product_df == "", 1, all), ]
  # 返回原始抓取的表,不做进一步加工
  product_df
}
