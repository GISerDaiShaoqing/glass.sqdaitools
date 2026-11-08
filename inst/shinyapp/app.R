# glass.sqdaitools 交互下载界面(底图与业务逻辑全调用包函数)
# 通过 glass_app() 启动;画 ROI 的方式:在地图上按两次点击给出矩形对角
library(shiny)
library(leaflet)

ui <- fluidPage(
  titlePanel("GLASS 数据下载助手 (glass.sqdaitools)"),
  sidebarLayout(
    sidebarPanel(
      width = 4,
      h4("1. 画研究区"),
      helpText("在地图上点击两次:第 1 次点对角一端,第 2 次点对角另一端,自动成矩形;",
               "点“重来”可重新画。"),
      actionButton("btn_reset_roi", "重来", class = "btn btn-outline-secondary btn-sm"),
      hr(),
      h4("2. 选择产品与时间"),
      selectInput("variant", "产品(已核验变体)",
                  choices = list(), selected = NULL),
      dateRangeInput("daterange", "日期区间", start = "2018-08-01",
                     end = "2018-08-12", min = "1981-01-01"),
      radioButtons("doys_mode", "DOY 选取方式",
                   choices = c(span = "span", start = "start"),
                   inline = TRUE),
      textInput("out_dir", "下载目录",
                value = file.path(tempdir(), "glass_download")),
      actionButton("btn_browse", "浏览文件夹…",
                   class = "btn btn-outline-secondary btn-sm"),
      helpText("点“浏览文件夹…”弹出系统目录选择对话框(本机运行时可用);",
               "也可直接在上方文本框输入路径。"),
      h4("3. 检索 / 下载"),
      actionButton("btn_list", "刷新文件清单", class = "btn btn-primary"),
      hr(),
      actionButton("btn_dl", "开始下载", class = "btn btn-success"),
      helpText("下载时上方显示进度条,逐文件更新(含当前文件名与状态);",
               "完成状态计入下方表格(含 glass_manifest.csv)。")
    ),
    mainPanel(
      width = 8,
      leafletOutput("map", height = 420),
      hr(),
      dataTableOutput("tbl_files"),
      tags$p(textOutput("txt_summary"))
    )
  )
)

server <- function(input, output, session) {
  reg <- glass.sqdaitools::glass_registry(verified_only = TRUE)
  updateSelectInput(session, "variant",
                    choices = reg$variant_id, selected = reg$variant_id[1])

  rv <- shiny::reactiveValues(
    manifest = NULL, status = NULL,
    roi = NULL,          # 已完成矩形:sfc
    roi_clicks = list(), # 进行中的点击
    msg = ""
  )

  output$map <- renderLeaflet({
    leaflet() |>
      addTiles(
        urlTemplate = paste0(
          "https://server.arcgisonline.com/ArcGIS/rest/services/",
          "World_Imagery/MapServer/tile/{z}/{y}/{x}"),
        group = "ArcGIS 影像(WGS84)",
        attribution = "Esri World Imagery"
      ) |>
      addTiles(
        urlTemplate = paste0(
          "https://webrd0{s}.is.autonavi.com/appmaptile?",
          "lang=zh_cn&size=1&scale=1&style=7&x={x}&y={y}&z={z}"),
        options = tileOptions(subdomains = "1234"),
        group = "高德街道(GCJ-02 有偏移)",
        attribution = "Amap"
      ) |>
      addLayersControl(
        baseGroups = c("ArcGIS 影像(WGS84)", "高德街道(GCJ-02 有偏移)"),
        options = layersControlOptions(collapsed = FALSE)
      ) |>
      setView(121.47, 31.23, zoom = 7)
  })

  # 点击采集:两次点击成矩形
  observeEvent(input$map_click, {
    click <- input$map_click
    if (is.null(click)) return(invisible())
    if (!is.null(rv$roi)) return(invisible())  # 已完成,等待“重来”
    if (length(rv$roi_clicks) == 0L) {
      rv$roi_clicks <- list(click)
      rv$msg <- "已记录对角第 1 点,请点击对角另一端。"
      leafletProxy("map") |> clearGroup("roi") |>
        clearGroup("roi_draft") |>
        addMarkers(lng = click$lng, lat = click$lat, group = "roi_draft")
    } else {
      p1 <- rv$roi_clicks[[1]]
      bbox <- sf::st_bbox(
        c(xmin = min(p1$lng, click$lng), xmax = max(p1$lng, click$lng),
          ymin = min(p1$lat, click$lat), ymax = max(p1$lat, click$lat)),
        crs = 4326L
      )
      rv$roi <- sf::st_as_sfc(bbox)
      rv$roi_clicks <- list()
      rv$msg <- NULL
    }
  })

  observeEvent(input$btn_reset_roi, {
    rv$roi <- NULL
    rv$roi_clicks <- list()
    rv$msg <- "已清空,重新点击两次画矩形。"
    leafletProxy("map") |> clearGroup("roi") |> clearGroup("roi_draft")
  })

  # 已画 ROI 的显示与瓦片覆盖
  observe({
    roi <- rv$roi
    if (is.null(roi)) return(invisible())
    ts <- tryCatch(glass.sqdaitools::glass_tiles_for_sf(roi),
                   error = function(e) NULL)
    p <- leafletProxy("map", data = rv$roi) |>
      clearGroup("roi_draft") |> clearGroup("roi") |> clearGroup("tiles")
    if (!is.null(roi)) {
      p <- p |> addPolygons(group = "roi", color = "#d95f02",
                            fillOpacity = 0.1, weight = 2.5)
    }
    if (!is.null(ts)) {
      p <- p |>
        addPolygons(group = "tiles", color = "#2b7a3d", fillColor = "#7fc97f",
                    fillOpacity = 0.15, weight = 2,
                    label = lapply(sprintf("h%02dv%02d", ts$h, ts$v), htmltools::HTML))
      rv$msg <- paste0("覆盖瓦片: ",
                       paste(sprintf("h%02dv%02d", ts$h, ts$v), collapse = ", "))
    }
  })

  # 系统目录选择对话框(本机 R 会话带 tcltk 时可用;否则提示手动输入)
  observeEvent(input$btn_browse, {
    if (!requireNamespace("tcltk", quietly = TRUE) ||
        !isTRUE(capabilities("tcltk"))) {
      showNotification("当前 R 不支持 tcltk 目录对话框,请直接输入下载目录。",
                       type = "warning")
      return(invisible())
    }
    chosen <- tryCatch(
      as.character(tcltk::tkchooseDirectory(
        title = "选择 GLASS 下载目录", mustexist = TRUE)),
      error = function(e) {
        showNotification(paste0("打开目录对话框失败: ", conditionMessage(e),
                                " — 请手动输入路径。"), type = "warning")
        character(0)
      })
    if (length(chosen) == 1L && nzchar(chosen)) {
      updateTextInput(session, "out_dir", value = chosen)
    }
  })

  run_fetch <- function(dry_run) {
    if (is.null(rv$roi)) {
      showNotification("请先在地图上点两次画出研究区矩形", type = "error")
      return(NULL)
    }
    p <- shiny::Progress$new(session, min = 0, max = 1)
    on.exit(p$close(), add = TRUE)
    # 检索清单阶段文件数未知:脉冲式;下载阶段由逐文件回调切换为真实进度
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
        showNotification(paste0("失败: ", conditionMessage(e)), type = "error")
        NULL
      })
    p$close()
    out
  }

  observeEvent(input$btn_list, {
    m <- run_fetch(dry_run = TRUE)
    if (!is.null(m)) {
      rv$manifest <- m
      rv$status <- NULL
    }
  })

  observeEvent(input$btn_dl, {
    m <- run_fetch(dry_run = FALSE)
    if (!is.null(m)) {
      rv$manifest <- m
      n_ok <- sum(m$status %in% c("downloaded", "resumed",
                                  "resumed_partial", "skipped"))
      rv$status <- sprintf("成功 %d / 共 %d 个文件(含跳过);输出目录: %s",
                           n_ok, nrow(m), input$out_dir)
    }
  })

  output$tbl_files <- renderDataTable({
    req(rv$manifest)
    cols <- intersect(c("filename", "tile", "year", "doy", "status", "size_bytes"),
                      names(rv$manifest))
    rv$manifest[, cols, drop = FALSE]
  }, options = list(pageLength = 12))

  output$txt_summary <- renderText({
    if (!is.null(rv$status)) rv$status
    else if (!is.null(rv$msg)) rv$msg
    else "先在地图上点两次画矩形,再检索清单。"
  })
}

shinyApp(ui, server)
