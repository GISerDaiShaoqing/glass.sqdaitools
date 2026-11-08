#' Download one GLASS file with resume support
#'
#' @description
#' Low-level httr2 wrapper. A HEAD size check is compared against the local
#' file, partial downloads (`.part`) are continued with an HTTP `Range`
#' request, and finished data are renamed into place so a crash never leaves
#' a truncated file masquerading as complete.
#'
#' @param url Direct file URL.
#' @param destfile Final local path.
#' @param overwrite If `TRUE`, a valid-looking local file is re-downloaded.
#' @param retries Passed to `httr2::req_retry`.
#' @param timeout_s Per-request timeout in seconds.
#'
#' @return One of `"downloaded"`, `"resumed"`, `"resumed_partial"`,
#'   `"skipped"` or `"failed"`; for `"failed"` the error message is kept as
#'   attribute `error`.
#'
#' @export
glass_download_file <- function(url, destfile, overwrite = FALSE,
                                retries = 3, timeout_s = 300) {
  remote_size <- .glass_remote_size(url, min(timeout_s, 60L))
  part <- paste0(destfile, ".part")

  if (file.exists(destfile) && !isTRUE(overwrite)) {
    local_size <- as.numeric(file.info(destfile)$size)
    if (is.na(remote_size) || local_size == remote_size) {
      return("skipped")
    }
  }

  if (file.exists(part)) {
    res <- tryCatch(
      .glass_resume(url, part, destfile, remote_size, retries, timeout_s),
      error = function(e) structure("failed", error = conditionMessage(e))
    )
    if (!is.null(res)) return(res)  # "resumed"/"resumed_partial"/"failed";NULL 时重下
  }

  # 全新下载:先写 .part,完成后原子 rename
  tryCatch(
    {
      httr2::request(url) |>
        httr2::req_user_agent(.glass_user_agent()) |>
        httr2::req_timeout(timeout_s) |>
        httr2::req_retry(max_tries = retries) |>
        httr2::req_perform(path = part)
      part_size <- as.numeric(file.info(part)$size)
      if (!is.finite(part_size) || part_size <= 0) {
        return(structure("failed", error = "empty download body"))
      }
      if (!is.na(remote_size) && part_size != remote_size) {
        return(structure("failed", error = "size mismatch vs Content-Length"))
      }
      if (file.exists(destfile)) unlink(destfile)
      if (isTRUE(file.rename(part, destfile))) "downloaded" else "failed"
    },
    error = function(e) structure("failed", error = conditionMessage(e))
  )
}

# HEAD 请求拿 Content-Length;失败仅损失跳过/校验能力
.glass_remote_size <- function(url, timeout_s = 60) {
  tryCatch(
    {
      r <- httr2::request(url) |>
        httr2::req_user_agent(.glass_user_agent()) |>
        httr2::req_timeout(timeout_s) |>
        httr2::req_method("HEAD") |>
        httr2::req_perform()
      s <- as.numeric(httr2::resp_headers(r)[["Content-Length"]])
      if (is.finite(s) && s > 0) s else NA_real_
    },
    error = function(e) NA_real_
  )
}

# 对已有 .part 做续传;返回 NULL 表示放弃续传(走全新下载)
.glass_resume <- function(url, part, destfile, remote_size, retries, timeout_s) {
  part_size <- as.numeric(file.info(part)$size)
  if (!is.finite(part_size) || part_size <= 0) {
    unlink(part)
    return(NULL)
  }
  if (is.finite(remote_size) && part_size >= remote_size) {
    unlink(part)  # .part 不小于目标:损坏,重下
    return(NULL)
  }

  r <- httr2::request(url) |>
    httr2::req_user_agent(.glass_user_agent()) |>
    httr2::req_timeout(timeout_s) |>
    httr2::req_retry(max_tries = retries) |>
    httr2::req_options(range = sprintf("bytes=%.0f-", part_size)) |>
    httr2::req_perform()
  st <- httr2::resp_status(r)

  if (st == 206L) {
    tmp <- tempfile(fileext = ".chunk")
    unlink(tmp)
    on.exit(unlink(tmp), add = TRUE)
    writeBin(httr2::resp_body_raw(r), tmp)
    file.append(part, tmp)
    new_size <- as.numeric(file.info(part)$size)
    if (is.na(remote_size) || new_size >= remote_size) {
      unlink(destfile)
      if (isTRUE(file.rename(part, destfile))) return("resumed")
      return(structure("failed", error = "rename after resume failed"))
    }
    return("resumed_partial")
  }

  if (st == 200L) {
    # 服务器不支持 Range:整份重下
    unlink(part)
    return(NULL)
  }
  structure("failed", error = paste0("HTTP ", st, " during resume"))
}

#' Batch download a GLASS file manifest
#'
#' Downloads every row of a manifest produced by [glass_list_files()] (or any
#' data frame with `filename` and `url` columns) into `out_dir`, with
#' politeness delays, per-file status tracking, and a `glass_manifest.csv`
#' ledger written to `out_dir`.
#'
#' @param manifest Data frame with at least `filename` and `url` columns, as
#'   returned by [glass_list_files()].
#' @param out_dir Destination directory; created if missing.
#' @param delay Seconds to wait between requests (be nice to the server).
#' @param overwrite Re-download existing valid files.
#' @param quiet Suppress per-file console messages.
#' @param progress Optional callback invoked after each file as
#'   `progress(i, n, filename, status)` (1-based index, total count, file
#'   name, download status); use it to drive GUI progress bars. Errors
#'   raised inside the callback are ignored.
#'
#' @return The manifest augmented with `destfile`, `status` and `size_bytes`
#'   columns (also written to `out_dir/glass_manifest.csv`).
#'
#' @export
glass_download <- function(manifest, out_dir, delay = 1, overwrite = FALSE,
                           quiet = FALSE, progress = NULL) {
  if (is.null(manifest) || !all(c("filename", "url") %in% names(manifest))) {
    glass_abort("`manifest` must have at least `filename` and `url` columns")
  }
  if (!is.null(progress) && !is.function(progress)) {
    glass_abort("`progress` must be NULL or a function")
  }
  if (nrow(manifest) == 0L) {
    message("empty manifest, nothing to download")
    return(manifest)
  }
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  }

  n <- nrow(manifest)
  status <- character(n)
  size_bytes <- rep(NA_real_, n)
  destfiles <- file.path(out_dir, manifest$filename)

  for (i in seq_len(n)) {
    if (!quiet) cat(sprintf("[%d/%d] %s\n", i, n, manifest$filename[i]))
    st <- glass_download_file(manifest$url[i], destfiles[i],
                              overwrite = overwrite)
    status[i] <- st
    probe <- if (file.exists(destfiles[i])) destfiles[i] else paste0(destfiles[i], ".part")
    if (file.exists(probe)) size_bytes[i] <- as.numeric(file.info(probe)$size)
    if (!is.null(progress)) {
      tryCatch(progress(i, n, manifest$filename[i], st), error = function(e) NULL)
    }
    if (i < n && delay > 0) Sys.sleep(delay)
  }

  res <- manifest
  res$destfile <- destfiles
  res$status <- status
  res$size_bytes <- size_bytes
  utils::write.csv(res, file.path(out_dir, "glass_manifest.csv"), row.names = FALSE)
  if (!quiet) {
    tbl <- table(factor(status, levels = c("downloaded", "resumed",
                                           "resumed_partial", "skipped", "failed")))
    cat("finished:", paste(names(tbl), as.integer(tbl), sep = "=", collapse = ", "), "\n")
    cat("manifest written to:", file.path(out_dir, "glass_manifest.csv"), "\n")
  }
  invisible(res)
}
