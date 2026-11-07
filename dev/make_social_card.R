# 开发用:生成 GitHub 社交分享卡 man/figures/social-preview.png(1280x640)
# 上传位置:GitHub 仓库 Settings -> General -> Social preview(手动,约 1MB 限制)
# 运行: Rscript dev/make_social_card.R(依赖 png 包读取 logo)

W <- 1280; H <- 640
png("man/figures/social-preview.png", width = W, height = H, bg = "#0F2C4A",
    res = 150, pointsize = 16, type = "cairo")
op <- par(mar = c(0, 0, 0, 0), xaxs = "i", yaxs = "i")
plot.new(); plot.window(xlim = c(0, W), ylim = c(0, H), asp = 1)

## ---------- 背景:垂直渐变(与 logo 一致:上深空蓝,下地表绿) ----------
pal <- colorRampPalette(c("#0D5C45", "#0F4460", "#122B4E"))(256)
n <- 256
ys <- seq(0, H, length.out = n + 1)
for (i in seq_len(n)) {
  idx <- ceiling(i / n * length(pal))            # 底部绿 -> 顶部蓝
  rect(0, ys[i], W, ys[i + 1], col = pal[idx], border = NA)
}

## ---------- 微弱横向格网 ----------
for (gy in seq(64, H - 64, by = 64)) {
  segments(0, gy, W, gy, col = "#FFFFFF10", lwd = 1)
}

## ---------- 星点 ----------
sx <- c(90, 210, 330, 470, 590, 150, 400, 700, 60, 540)
sy <- c(560, 590, 545, 600, 570, 615, 620, 610, 520, 625)
sc <- c(0.7, 1.0, 0.6, 0.9, 0.7, 1.1, 0.6, 0.8, 0.7, 0.6)
points(sx, sy, pch = 16, cex = sc, col = "#FFFFFF4D")

## ---------- 左下角瓦片马赛克(呼应 logo 的 5x5 母题,置于页脚之下) ----------
ts <- 28; gp <- 6
for (jx in 0:3) for (jy in 0:1) {
  xa <- 64 + jx * (ts + gp)
  ya <- 14 + jy * (ts + gp)
  a <- max(0.05, 0.13 - 0.03 * jy - 0.022 * jx)
  rect(xa, ya, xa + ts, ya + ts,
       col = adjustcolor("#9FE3D0", alpha.f = a),
       border = adjustcolor("#9FE3D0", alpha.f = a * 1.8), lwd = 1.5)
}

## ---------- 右侧:六边形 logo ----------
logo <- png::readPNG("man/figures/logo.png")
lw <- 560 * dim(logo)[2] / dim(logo)[1]           # 高 560,保持宽高比
rasterImage(logo, xleft = 1244 - lw, ybottom = 40, xright = 1244, ytop = 600)

## ---------- 左侧文字块 ----------
TXT_X <- 66; MAXW <- 620
fit_cex <- function(s, cex0, maxw = MAXW, ...) {
  while (cex0 > 0.4 && strwidth(s, cex = cex0, units = "user", ...) > maxw)
    cex0 <- cex0 - 0.02
  cex0
}

# 眉题
text(TXT_X, 500, "GLASS  ·  GLOBAL LAND SURFACE SATELLITE PRODUCTS",
     cex = 0.66, font = 2, col = "#7FD1C0", adj = 0)

# 包名(与 logo 同款粗斜体,自适配宽度)
nm <- "glass.sqdaitools"
text(TXT_X, 408, nm, cex = fit_cex(nm, 3.2, font = 4), font = 4,
     col = "#FFFFFF", adj = 0)

# 强调线
segments(TXT_X, 348, TXT_X + 300, 348, col = "#7FD1C0", lwd = 8, lend = "butt")
segments(TXT_X + 312, 348, TXT_X + 380, 348, col = "#9FD8E8", lwd = 8, lend = "butt")

# 英文副题
en <- "Download & process GLASS land surface products in R"
text(TXT_X, 282, en, cex = fit_cex(en, 1.05), col = "#CDE7F2", adj = 0)

# 中文副题(两行)
zh1 <- "GLASS 数据全生命周期 R 工具包"
text(TXT_X, 218, zh1, cex = fit_cex(zh1, 1.08, family = "Microsoft YaHei"),
     family = "Microsoft YaHei", col = "#FFFFFF", adj = 0)
zh2 <- "产品登记表 · 瓦片映射 · 断点续传下载 · terra 后处理"
text(TXT_X, 158, zh2, cex = fit_cex(zh2, 0.82, family = "Microsoft YaHei"),
     family = "Microsoft YaHei", col = "#9FD8E8", adj = 0)

# 页脚
foot <- "github.com/GISerDaiShaoqing/glass.sqdaitools"
text(TXT_X, 104, foot, cex = 0.68, family = "mono", col = "#FFFFFF78", adj = 0)

dev.off()
par(op)
cat("social preview written: man/figures/social-preview.png\n")
