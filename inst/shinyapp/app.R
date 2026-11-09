# glass.sqdaitools 交互下载界面(底图与业务逻辑全调用包函数)
# 通过 glass_app() 启动。
#
# 绘制规则:
#   漫游模式(默认) —— 点击/拖动地图只用于浏览,不画框;
#   绘制模式 —— 按钮切到"退出绘制"后,点击两次给出矩形对角,画完自动退回漫游。
# 目录选择:安装 shinyFiles 后可用"浏览…"在本页弹窗内选择目录(不阻塞应用);
#   未安装时直接在文本框输入路径。

library(shiny)
library(leaflet)

has_dt       <- requireNamespace("DT", quietly = TRUE)
has_shinydir <- requireNamespace("shinyFiles", quietly = TRUE)

# 包版本徽标:源码树与安装目录同构(优雅 app 目录的上层就是包根)
pkg_ver <- {
  desc <- file.path(dirname(system.file("shinyapp", package = "glass.sqdaitools")),
                    "DESCRIPTION")
  if (file.exists(desc)) as.character(read.dcf(desc, "Version")[1, 1]) else ""
}

logo_src <- "logo.png"

# 跳转徽章:点击写入 Shiny 输入,由 R 侧 utils::browseURL 打开系统默认浏览器
# (RStudio Viewer 对 target="_blank" 的新窗口请求会吞掉;
#  经后端打开的方式在 Viewer 与普通浏览器里都必定弹出)
.jump_link <- function(href, label, ic = NULL) {
  shiny::tags$a(
    href = "#",
    class = "badge text-bg-light jump-badge",
    onclick = sprintf(
      "Shiny.setInputValue('glass_open_url', '%s', {priority: 'event'}); return false;",
      href),
    if (!is.null(ic)) shiny::icon(ic) else NULL,
    label
  )
}

card_css <- "
  body { background: #f4f7f5; }
  .glass-card { border-radius: .8rem; box-shadow: 0 1px 4px rgba(0,0,0,.07); }
  #map { border-radius: .5rem; }
  .glass-hero { background: linear-gradient(120deg,#1b5e20 0%,#2e7d32 45%,#558b2f 100%);
                border-radius: .7rem; padding: .45rem .75rem; }
  .glass-hero-card { flex-shrink: 0; }
  .glass-map-card  { flex-shrink: 0; }
  .glass-title { font-weight: 600; }
  .glass-help { font-size: .76rem; color: #6c757d; margin-top: .1rem; line-height: 1.25; }
  .glass-section { font-weight: 600; color: #2e7d32; border-bottom: 1px solid #e3e8e5;
                   padding-bottom: .16rem; margin-bottom: .36rem; margin-top: .45rem;
                   font-size: .9rem; }
  .glass-section i { margin-right: .3rem; color: #2e7d32; }
  .sidebar-content { padding: .5rem .7rem .55rem; }
  .sidebar-content .shiny-input-container { margin-bottom: .4rem; }
  .sidebar-content label { margin-bottom: .14rem; font-size: .84rem; }
  .sidebar-content .input-daterange .form-control { padding: .2rem .22rem;
                                                    font-size: .8rem; letter-spacing: 0; }
  .card-header > .d-flex { width: 100%; }
  #btn_draw, #btn_reset_roi, #btn_list, #btn_dl { padding: .26rem .45rem; font-size: .86rem; }
  .jump-badge { font-size: .73rem; padding: .3em .55em; }
  .stat-chip { flex: 1; background: #fff; border: 1px solid #e3e8e5;
               border-radius: .5rem; padding: .22rem .2rem .28rem; text-align: center; }
  .stat-chip .s-label { font-size: .68rem; color: #6c757d; line-height: 1.1; }
  .stat-chip .s-value { font-size: .92rem; font-weight: 700; margin-top: .05rem; }
  .chip-green { border-top: 3px solid #2e7d32; }
  .chip-teal  { border-top: 3px solid #1b9e8f; }
  .chip-ok    { border-top: 3px solid #43a047; }
"

ui <- bslib::page_fillable(
  title = "GLASS 数据下载助手",
  theme = bslib::bs_theme(version = 5, primary = "#2e7d32"),
  padding = ".6rem",
  shiny::tags$head(shiny::tags$style(shiny::HTML(card_css))),
  # 绘制/漫游状态消息:光标 + 按钮样式
  shiny::tags$script(shiny::HTML("
    Shiny.addCustomMessageHandler('glass_draw_state', function(m) {
      var map = document.getElementById('map');
      if (map) map.style.cursor = m.on ? 'crosshair' : '';
      var b = document.getElementById('btn_draw');
      if (b) {
        b.classList.toggle('btn-warning', !!m.on);
        b.classList.toggle('btn-outline-primary', !m.on);
      }
    });
  ")),
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      width = 262, open = TRUE,
      shiny::div(
        shiny::div(class = "glass-section", shiny::icon("draw-polygon"), "1 · 研究区"),
        shiny::actionButton("btn_draw", "开始绘制 ROI",
                            icon = shiny::icon("crosshairs"),
                            class = "btn btn-outline-primary w-100"),
        shiny::actionButton("btn_reset_roi", "清空重画",
                            icon = shiny::icon("eraser"),
                            class = "btn btn-outline-secondary btn-sm w-100 mt-1"),
        shiny::p(class = "glass-help",
                 "漫游=自由浏览;点“开始绘制 ROI”后点击两次成对角,自动回漫游。"),
        shiny::div(class = "glass-section", shiny::icon("calendar-week"), "2 · 产品与时间"),
        shiny::selectInput("variant", "产品(已核验变体)",
                           choices = list(), selected = NULL),
        shiny::textOutput("txt_variant_note"),
        shiny::dateRangeInput("daterange", "日期区间", start = "2018-08-01",
                              end = "2018-08-12", min = "1981-01-01"),
        shiny::radioButtons("doys_mode", "DOY 选取方式",
                            choices = c(span = "span", start = "start"),
                            inline = TRUE),
        shiny::div(class = "glass-section", shiny::icon("folder-open"), "3 · 下载目录"),
        shiny::div(class = "d-flex gap-1",
                   shiny::div(style = "flex: 1 1 auto; min-width: 0;",
                              shiny::textInput("out_dir", "下载目录", width = "100%",
                                               placeholder = "相对或绝对路径,如 ./glass_dl")),
                   if (has_shinydir) {
                     shiny::div(style = "align-self: flex-end; flex: 0 0 auto;",
                                shinyFiles::shinyDirButton(id = "browse_dir",
                                                           label = "浏览",
                                                           title = "选择 GLASS 下载目录",
                                                           icon = shiny::icon("folder-open"),
                                                           class = "btn btn-outline-secondary btn-sm"))
                   }),
        shiny::p(class = "glass-help",
                 if (has_shinydir) {
                   "点“浏览”在本页弹窗内选目录,也可直接输入路径。"
                 } else {
                   "未检测到 shinyFiles 包,请直接输入路径;或安装 shinyFiles 后重启应用。"
                 }),
        shiny::div(class = "glass-section", shiny::icon("cloud-arrow-down"), "4 · 检索与下载"),
        shiny::actionButton("btn_list", "刷新文件清单",
                            icon = shiny::icon("list-check"),
                            class = "btn btn-primary w-100"),
        shiny::actionButton("btn_dl", "开始下载",
                            icon = shiny::icon("download"),
                            class = "btn btn-success w-100 mt-1"),
        shiny::p(class = "glass-help",
                 "下载逐文件进度;完成后写 glass_manifest.csv。")
      )
    ),
    # ---------- 主区 ----------
    # 顶部横幅(含快速跳转徽章)
    bslib::card(class = "glass-card mb-2 glass-hero-card",
                shiny::div(class = "glass-hero d-flex align-items-center justify-content-between gap-3",
                           shiny::div(class = "d-flex align-items-center gap-2",
                                      shiny::img(src = logo_src, height = "40"),
                                      shiny::div(
                                        shiny::h5(class = "glass-title m-0 text-white",
                                                  "GLASS 数据下载助手"),
                                        shiny::div(class = "small text-white-50",
                                                   "画研究区 → 预览清单 → 批量下载;配套桌面下载管理器 D3L Tool。"))),
                           shiny::div(class = "d-flex flex-column align-items-end gap-1",
                                      shiny::tags$a(
                                        href = "#",
                                        class = "badge text-bg-light",
                                        onclick = sprintf(
                                          "Shiny.setInputValue('glass_open_url', '%s', {priority: 'event'}); return false;",
                                          "https://gisersqdai.top/glass.sqdaitools/"),
                                        sprintf("glass.sqdaitools v%s", pkg_ver)),
                                      shiny::div(class = "d-flex gap-1",
                                                 .jump_link("https://gisersqdai.top/mycv/",
                                                            "作者主页", ic = "user"),
                                                 .jump_link("https://gisersqdai.top/glass.sqdaitools/",
                                                            "本包文档", ic = "box"),
                                                 .jump_link("https://gisersqdai.top/D3LTool/",
                                                            "D3L Tool", ic = "desktop"),
                                                 .jump_link("https://glass.hku.hk/",
                                                            "GLASS 官网", ic = "globe"))))),
    # 主区地图(随窗口伸缩,52% 视口高)
    bslib::card(class = "glass-card mb-2 glass-map-card",
                height = "52%",
                full_screen = TRUE,
                leaflet::leafletOutput("map", height = "100%"),
                bslib::card_footer(
                  shiny::span(class = "text-muted small",
                              "底图:Esri World Imagery(WGS84)/ 高德街道(GCJ-02,偏移约 500 m);瓦片以绿色半透明显示。"))),
    # 文件清单(填满剩余高度;头部为状态芯片条)
    bslib::card(class = "glass-card mt-2",
                fill = TRUE,
                full_screen = TRUE,
                bslib::card_header(
                  shiny::div(class = "d-flex gap-1 flex-nowrap",
                             shiny::div(class = "stat-chip chip-green",
                                        shiny::div(class = "s-label", "瓦片数"),
                                        shiny::div(class = "s-value",
                                                   shiny::textOutput("vb_tiles"))),
                             shiny::div(class = "stat-chip chip-teal",
                                        shiny::div(class = "s-label", "清单数"),
                                        shiny::div(class = "s-value",
                                                   shiny::textOutput("vb_manifest"))),
                             shiny::div(class = "stat-chip chip-ok",
                                        shiny::div(class = "s-label", "下载完成"),
                                        shiny::div(class = "s-value",
                                                   shiny::textOutput("vb_done"))))),
                if (has_dt) DT::DTOutput("tbl_files") else shiny::dataTableOutput("tbl_files"),
                bslib::card_footer(shiny::uiOutput("txt_summary")))
  )
)

server <- function(input, output, session) {
  reg <- glass.sqdaitools::glass_registry(verified_only = TRUE)
  shiny::updateSelectInput(session, "variant",
                           choices = reg$variant_id, selected = reg$variant_id[1])

  rv <- shiny::reactiveValues(
    draw_mode  = FALSE,   # FALSE 漫游 / TRUE 绘制
    roi        = NULL,    # 已完成矩形:sfc
    roi_clicks = list(),  # 绘制进行中的点击
    manifest   = NULL,
    tiles_txt  = "-",
    manifest_n = "-",
    done_txt   = "-",
    msg        = ""
  )

  output$map <- leaflet::renderLeaflet({
    leaflet::leaflet() |>
      leaflet::addTiles(
        urlTemplate = paste0(
          "https://server.arcgisonline.com/ArcGIS/rest/services/",
          "World_Imagery/MapServer/tile/{z}/{y}/{x}"),
        group = "ArcGIS 影像(WGS84)",
        attribution = "Esri World Imagery"
      ) |>
      leaflet::addTiles(
        urlTemplate = paste0(
          "https://webrd0{s}.is.autonavi.com/appmaptile?",
          "lang=zh_cn&size=1&scale=1&style=7&x={x}&y={y}&z={z}"),
        options = leaflet::tileOptions(subdomains = "1234"),
        group = "高德街道(GCJ-02 有偏移)",
        attribution = "Amap"
      ) |>
      leaflet::addLayersControl(
        baseGroups = c("ArcGIS 影像(WGS84)", "高德街道(GCJ-02 有偏移)"),
        options = leaflet::layersControlOptions(collapsed = FALSE)
      ) |>
      leaflet::setView(121.47, 31.23, zoom = 7)
  })

  # ---- 跳转徽章:外面的系统默认浏览器(兼容 RStudio Viewer) ----
  shiny::observeEvent(input$glass_open_url, ignoreNULL = TRUE, {
    u <- input$glass_open_url
    if (is.character(u) && length(u) == 1L && nzchar(u)) {
      tryCatch(utils::browseURL(u),
               error = function(e) shiny::showNotification(
                 paste0("打开网页失败: ", conditionMessage(e)), type = "error"))
    }
  })

  # ---- 绘制 / 漫游状态机 ----
  set_draw_mode <- function(on) {
    rv$draw_mode <- isTRUE(on)
    session$sendCustomMessage("glass_draw_state", list(on = isTRUE(on)))
    if (isTRUE(on)) {
      rv$roi        <- NULL
      rv$roi_clicks <- list()
      rv$tiles_txt  <- "-"
      leaflet::leafletProxy("map") |>
        leaflet::clearGroup("roi") |>
        leaflet::clearGroup("roi_draft") |>
        leaflet::clearGroup("tiles")
      rv$msg <- "绘制模式:点击地图两次,给出矩形对角两端。"
    } else {
      rv$roi_clicks <- list()
      leaflet::leafletProxy("map") |> leaflet::clearGroup("roi_draft")
      if (is.null(rv$roi)) {
        rv$msg <- "漫游模式:地图可自由缩放平移,点击“开始绘制 ROI”画研究区。"
      }
    }
    shiny::updateActionButton(
      session, "btn_draw",
      label = if (isTRUE(on)) "退出绘制(漫游)" else "开始绘制 ROI",
      icon  = shiny::icon(if (isTRUE(on)) "hand" else "crosshairs"))
  }

  shiny::observeEvent(input$btn_draw, set_draw_mode(!rv$draw_mode))
  shiny::observeEvent(input$btn_reset_roi, set_draw_mode(TRUE))

  # 点击采集:仅绘制模式生效,两次点击成矩形
  shiny::observeEvent(input$map_click, {
    if (!isTRUE(rv$draw_mode)) {
      if (is.null(rv$roi)) {
        rv$msg <- "漫游模式:此时点击地图不画框;请先点左侧“开始绘制 ROI”。"
      }
      return(invisible())
    }
    click <- input$map_click
    if (length(rv$roi_clicks) == 0L) {
      rv$roi_clicks <- list(click)
      rv$msg <- "已记录矩形对角第 1 点,请再点击另一端。"
      leaflet::leafletProxy("map") |>
        leaflet::clearGroup("roi") |>
        leaflet::clearGroup("tiles") |>
        leaflet::addMarkers(lng = click$lng, lat = click$lat, group = "roi_draft")
    } else {
      p1 <- rv$roi_clicks[[1]]
      bbox <- sf::st_bbox(
        c(xmin = min(p1$lng, click$lng), xmax = max(p1$lng, click$lng),
          ymin = min(p1$lat, click$lat), ymax = max(p1$lat, click$lat)),
        crs = 4326L)
      rv$roi <- sf::st_as_sfc(bbox)
      set_draw_mode(FALSE)   # 画完自动回到漫游
    }
  })

  # 已画 ROI 的显示与瓦片覆盖
  shiny::observe({
    roi <- rv$roi
    if (is.null(roi)) return(invisible())
    ts <- tryCatch(glass.sqdaitools::glass_tiles_for_sf(roi),
                   error = function(e) NULL)
    p <- leaflet::leafletProxy("map") |>
      leaflet::clearGroup("roi_draft") |>
      leaflet::clearGroup("roi") |>
      leaflet::clearGroup("tiles")
    p <- p |>
      leaflet::addPolygons(data = roi, group = "roi", color = "#d95f02",
                           fillOpacity = 0.1, weight = 2.5)
    rv$msg <- "研究区已生成,可在“检索与下载”里预览清单。"
    if (!is.null(ts) && nrow(ts) > 0L) {
      p <- p |>
        leaflet::addPolygons(data = ts, group = "tiles", color = "#2b7a3d",
                             fillColor = "#7fc97f", fillOpacity = 0.15,
                             weight = 2,
                             label = lapply(sprintf("h%02dv%02d", ts$h, ts$v),
                                            htmltools::HTML))
      rv$tiles_txt <- sprintf("%d 个:%s", nrow(ts),
                              paste(sprintf("h%02dv%02d", ts$h, ts$v),
                                    collapse = ", "))
      rv$msg <- paste0("覆盖瓦片: ",
                       paste(sprintf("h%02dv%02d", ts$h, ts$v), collapse = ", "))
    } else {
      rv$tiles_txt <- "0(研究区可能超出正弦投影范围)"
    }
  })

  # ---- 目录选择(shinyFiles 页面内弹窗,不阻塞、不冻结) ----
  # 根节点自行枚举:getVolumes() 在部分 Windows 构建下盘符解析会错位
  if (has_shinydir) {
    win_roots <- function() {
      d <- LETTERS[file.exists(paste0(LETTERS, ":/"))]
      out <- setNames(paste0(d, ":/"), paste0(d, " 盘"))
      out <- out[names(out) != "A 盘"]   # 软驱根无意义
      out
    }
    roots <- c(win_roots(),
               项目目录 = getwd(),
               用户主目录 = path.expand("~"))
    shinyFiles::shinyDirChoose(input, "browse_dir", roots = roots)
    shiny::observeEvent(input$browse_dir, ignoreNULL = TRUE, {
      p <- tryCatch(shinyFiles::parseDirPath(roots, input$browse_dir),
                    error = function(e) character(0))
      if (length(p) == 1L && nzchar(p)) {
        shiny::updateTextInput(session, "out_dir", value = p)
      }
    })
  }

  # 产品信息提示(含档案布局预检提示)
  output$txt_variant_note <- shiny::renderText({
    ok <- input$variant %in% reg$variant_id
    if (!ok) return("")
    i <- which(reg$variant_id == input$variant)
    res_txt <- reg$res[i]
    if (is.na(res_txt)) res_txt <- "CMG(全球)"
    tem_txt <- reg$temporal_res[i]
    if (is.na(tem_txt) || !nzchar(tem_txt)) tem_txt <- "未标注"
    pre <- ""
    if (identical(reg$layout[i], "flat")) {
      pre <- " 静态整幅集合:下载全量文件(日期不参与检索)。"
    }
    paste0("空间 ", res_txt, " · 周期 ", tem_txt, ".", pre)
  })

  run_fetch <- function(dry_run) {
    if (is.null(rv$roi)) {
      shiny::showNotification("请先在地图上画出研究区矩形", type = "error")
      return(NULL)
    }
    if (input$daterange[1] > input$daterange[2]) {
      shiny::showNotification("日期区间:起始日期应不晚于结束日期", type = "error")
      return(NULL)
    }
    if (!dry_run && !nzchar(trimws(paste(input$out_dir)))) {
      shiny::showNotification("请先指定下载目录(浏览选择或直接输入路径)",
                              type = "error")
      return(NULL)
    }
    p <- shiny::Progress$new(session, min = 0, max = 1)
    on.exit(p$close(), add = TRUE)
    p$set(message = if (dry_run) "检索文件清单..." else "检索清单,随后开始下载...",
          value = NULL)
    prog_cb <- if (dry_run) NULL else function(i, n, fname, st) {
      p$set(message = "正在下载", value = i / n,
            detail = sprintf("%d/%d  %s  [%s]", i, n, fname, st))
    }
    out <- tryCatch(
      glass.sqdaitools::glass_fetch(
        input$variant,
        from = input$daterange[1], to = input$daterange[2],
        roi = rv$roi, doys_mode = input$doys_mode,
        out_dir = input$out_dir,
        dry_run = dry_run, quiet = TRUE, progress = prog_cb
      ),
      error = function(e) {
        shiny::showNotification(
          paste0("失败(", input$variant, "): ", conditionMessage(e)),
          type = "error", duration = 12)
        NULL
      })
    out
  }

  shiny::observeEvent(input$btn_list, {
    m <- run_fetch(dry_run = TRUE)
    if (!is.null(m)) {
      rv$manifest   <- m
      rv$manifest_n <- sprintf("%d", nrow(m))
      rv$done_txt   <- "-"
      if (nrow(m) == 0L) {
        rv$msg <- paste0("该产品目录下没有匹配的文件;请确认所选日期区间落在观测覆盖内,",
                         "或到 GLASS 官网核对该变体的存档路径。")
      }
    }
  })

  shiny::observeEvent(input$btn_dl, {
    m <- run_fetch(dry_run = FALSE)
    if (!is.null(m)) {
      rv$manifest   <- m
      rv$manifest_n <- sprintf("%d", nrow(m))
      n_ok <- sum(m$status %in% c("downloaded", "resumed",
                                  "resumed_partial", "skipped"))
      rv$done_txt <- sprintf("%d / %d", n_ok, nrow(m))
      rv$status   <- sprintf("下载完成:成功 %d / 共 %d 个文件(含跳过);输出目录: %s",
                             n_ok, nrow(m), input$out_dir)
    }
  })

  output$vb_tiles    <- shiny::renderText(rv$tiles_txt)
  output$vb_manifest <- shiny::renderText(if (!is.null(rv$manifest)) rv$manifest_n else "-")
  output$vb_done     <- shiny::renderText(rv$done_txt)

  output$tbl_files <- if (has_dt) {
    DT::renderDT({
      req(rv$manifest)
      cols <- intersect(c("filename", "tile", "year", "doy", "status", "size_bytes"),
                        names(rv$manifest))
      rv$manifest[, cols, drop = FALSE]
    }, options = list(pageLength = 10, scrollX = TRUE, server = FALSE))
  } else {
    shiny::renderDataTable({
      req(rv$manifest)
      cols <- intersect(c("filename", "tile", "year", "doy", "status", "size_bytes"),
                        names(rv$manifest))
      rv$manifest[, cols, drop = FALSE]
    }, options = list(pageLength = 10))
  }

  output$txt_summary <- shiny::renderUI({
    if (!is.null(rv$status)) {
      shiny::div(class = "text-success small", rv$status)
    } else if (!is.null(rv$msg)) {
      shiny::div(class = "text-muted small", rv$msg)
    } else {
      shiny::div(class = "text-muted small",
                 "先点左侧“开始绘制 ROI”画研究区,再刷新清单。")
    }
  })
}

shiny::shinyApp(ui, server)
