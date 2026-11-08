#' GLASS sinusoidal tile lookup table
#'
#' @description
#' The global 36 x 18 ordered grid used by tiled GLASS products (equivalent to
#' the MODIS sinusoidal tile system). Each row holds the WGS84 geographic
#' bounding box of one tile; tiles outside the projection footprint carry
#' `NA` bounds and `valid = FALSE`.
#'
#' `h` is the horizontal tile index (0-35, west to east) and `v` is the
#' vertical index (0-17, north to south). Tiles are referenced in file names
#' and archive paths as `h<h>v<v>`, e.g. `h28v05`.
#'
#' The source table was produced by projecting the bounding rectangles of the
#' sinusoidal tiles (`+proj=sinu` with sphere radius 6371007.181, tile width
#' and height 1111950.51966667 m) to WGS84; see the original `glass_tiles.tsv`
#' in `data-raw/`. Bounds are those of the curved tile polygons, so a strict
#' bounding-box intersection test may slightly over-select corner tiles.
#' Use [glass_tiles_for_bbox()] or [glass_tiles_for_sf()] for exact selection.
#'
#' @format A tibble with 648 rows and 7 columns:
#' \describe{
#'   \item{h}{Horizontal tile index \(0-35\)}
#'   \item{v}{Vertical tile index \(0-17\)}
#'   \item{lon_min, lon_max, lat_min, lat_max}{WGS84 bounds of the tile; `NA` if not covered by the projection}
#'   \item{valid}{`TRUE` when the tile lies inside the sinusoidal footprint}
#' }
#' @keywords datasets
"glass_tiles"

#' GLASS product registry
#'
#' A curated registry of the GLASS product archive (glass.hku.hk/archive/),
#' one row per archive variant (product x source x resolution). It stores the
#' archive URL layout, the observed year coverage, and—for the variants whose
#' sample files have been checked—file-name fragments and band scaling
#' metadata used by [glass_read()].
#'
#' Built by `data-raw/build_registry.R` from an archive directory scan
#' (`data-raw/archive_scan.csv`) plus hand verification against sample HDF
#' granules.
#'
#' @format A tibble with one row per archive variant:
#' \describe{
#'   \item{product}{Product directory under /archive/, e.g. "LAI"}
#'   \item{long_name}{Human-readable product name}
#'   \item{variant_id}{Unique key, e.g. "LAI_MODIS_250M"}
#'   \item{source}{Source/series sub-directory, e.g. "MODIS", "AVHRR"}
#'   \item{res}{Resolution sub-directory, e.g. "250M"; `NA` if absent}
#'   \item{layout}{Archive layout: "year_doy" (year/composite folders), "flat" (static file collection), "year_files" (granules directly under year folders, e.g. AVHRR CMG) or "year_yyyddd" (daily YYYYDDD folders, e.g. AWGF LST)}
#'   \item{observed_years}{Year coverage observed in the directory tree, e.g. "2000-2025"}
#'   \item{start_year, end_year}{First/last observed year, `NA` if unobserved}
#'   \item{cadence_days}{Days per synthesis cycle, e.g. 8 for the 8-day products}
#'   \item{temporal_res}{Temporal resolution label, e.g. "8 days", "daily"}
#'   \item{version}{Product version fragment of the file names, e.g. "V60"}
#'   \item{code}{GLASS dataset code fragment, e.g. "GLASS01D01"}
#'   \item{layer}{Layer name suffix in file names, e.g. "LAI"; `NA` when files carry no suffix}
#'   \item{fill_value}{Fill value of the raw storage, e.g. 255}
#'   \item{scale_factor}{Scale factor applied to raw values, e.g. 0.01}
#'   \item{valid_min, valid_max}{Valid data range after scaling}
#'   \item{verified}{`TRUE` for variants where naming and band metadata were validated against a real granule}
#'   \item{url_root}{Base URL of the variant, i.e. /archive/product/source/res/}
#'   \item{notes}{Free-text notes}
#' }
#' @keywords datasets
"glass_products"
