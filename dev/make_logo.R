# 开发用:生成六边形包图标 man/figures/logo.png(零额外依赖,base R 绘制)
# 运行: Rscript dev/make_logo.R
dir.create("man/figures", showWarnings = FALSE, recursive = TRUE)

W <- 1200; H <- 1366
png("man/figures/logo.png", width = W, height = H, bg = NA, res = 150)
op <- par(mar = c(0, 0, 0, 0), xaxs = "i", yaxs = "i")
plot.new(); plot.window(xlim = c(-1, 1), ylim = c(-1, 1))

# ---------- 六边形(pointy-top)与边界函数 ----------
R <- 0.94
ang <- (90 + 60 * (0:5)) * pi / 180   # 90,150,210,270,330,30
v <- cbind(R * cos(ang), R * sin(ang))
vx <- v[, 1]; vy <- v[, 2]

hex_span <- function(y) {
  xs <- numeric(0)
  for (i in 1:6) {
    j <- i %% 6 + 1
    y1 <- vy[i]; y2 <- vy[j]
    if (abs(y1 - y2) < 1e-9) next
    if (y >= min(y1, y2) && y <= max(y1, y2)) {
      t <- (y - y1) / (y2 - y1)
      xs <- c(xs, vx[i] + t * (vx[j] - vx[i]))
    }
  }
  c(min(xs), max(xs))
}

# ---------- 背景:垂直渐变(上=深空蓝,下=地表绿) ----------
pal <- colorRampPalette(c("#0D5C45", "#0F4460", "#122B4E"))(256)  # 从下到上
n <- 256
ys <- seq(-R, R, length.out = n + 1)
for (i in seq_len(n)) {
  y0 <- ys[i]; y1 <- ys[i + 1]
  ym <- (y0 + y1) / 2
  sp0 <- hex_span(y0); sp1 <- hex_span(y1)
  idx <- ceiling((ym + R) / (2 * R) * n)          # ym=-R -> 1(绿底), ym=R -> 256(蓝顶)
  polygon(c(sp0[1], sp1[1], sp1[2], sp0[2]),
          c(y0, y1, y1, y0), col = pal[idx], border = NA)
}

# ---------- 微弱横向格网 ----------
for (k in 1:9) {
  yy <- -R + (2 * R) * k / 10
  sp <- hex_span(yy)
  lines(c(sp[1], sp[2]), c(yy, yy), col = "#FFFFFF12", lwd = 1.2)
}

# ---------- 星点 ----------
sx <- c(-0.66, -0.45, -0.30, 0.36, 0.52, 0.68, 0.22, -0.58, 0.62, 0.05, -0.15, 0.44)
sy <- c(0.62, 0.44, 0.74, 0.66, 0.52, 0.30, 0.82, -0.30, -0.44, -0.60, -0.74, -0.18)
sc <- c(0.7, 1.1, 0.6, 0.9, 1.2, 0.7, 0.8, 1.0, 0.6, 1.1, 0.7, 0.9)
points(sx, sy, pch = 16, cex = sc, col = "#FFFFFF55")

# ---------- 轨道虚线椭圆 ----------
th <- seq(0, 2 * pi, length.out = 361)
lines(0.72 * cos(th), 0.28 * sin(th) + 0.10, lty = "2233", lwd = 3, col = "#7FD1C0AA")

# ---------- 简笔卫星 ----------
cy <- 0.10
panel_h <- 0.11
for (s in c(-1, 1)) {
  x0 <- if (s < 0) -0.50 else 0.14
  x1 <- if (s < 0) -0.14 else 0.50
  rect(x0, cy - panel_h / 2, x1, cy + panel_h / 2,
       col = "#0F3D63", border = "#BFE9F7", lwd = 4)
  for (g in 1:2) {
    gx <- x0 + (x1 - x0) * g / 3
    lines(c(gx, gx), c(cy - panel_h / 2, cy + panel_h / 2),
          col = "#BFE9F7", lwd = 2.4)
  }
}
# 连接桁架(两小块,分别位于 body 与翼之间)
rect(-0.145, cy - 0.018, -0.095, cy + 0.018, col = "#BFE9F7", border = NA)
rect(0.095,  cy - 0.018, 0.145,  cy + 0.018, col = "#BFE9F7", border = NA)
# 本体
rect(-0.10, cy - 0.085, 0.10, cy + 0.085,
     col = "#E8F4FA", border = "#BFE9F7", lwd = 4)
# 桅杆 + 天线锅 + 信号波
lines(c(0, 0), c(cy + 0.085, cy + 0.155), col = "#BFE9F7", lwd = 3)
th2 <- seq(0, pi, length.out = 60)
lines(0.062 * cos(th2), cy + 0.155 + 0.062 * sin(th2), col = "#BFE9F7", lwd = 4)
for (rr in c(0.10, 0.155)) {
  th3 <- seq(pi * 0.18, pi * 0.82, length.out = 40)
  lines(rr * cos(th3), cy + 0.175 + rr * sin(th3), col = "#7FD1C0", lwd = 3)
}

# ---------- 底部 5x5 瓦片马赛克(裁剪进六边形,作为包名背景) ----------
# Sutherland-Hodgman 凸多边形裁剪:瓦片矩形 x 六边形
cross2 <- function(u, v) u[1] * v[2] - u[2] * v[1]
.clip_convex <- function(poly, clip) {
  out <- poly
  m <- nrow(clip)
  for (i in seq_len(m)) {
    a <- clip[i, ]; b <- clip[i %% m + 1, ]
    e <- b - a
    inp <- out
    n <- nrow(inp)
    out <- matrix(numeric(0), ncol = 2)
    if (n == 0) break
    for (j in seq_len(n)) {
      p <- inp[j, ]; q <- inp[j %% n + 1, ]
      sp <- cross2(e, p - a) >= 0
      sq <- cross2(e, q - a) >= 0
      if (sp) out <- rbind(out, p)
      if (sp != sq) {
        d <- q - p
        denom <- cross2(d, e)
        if (abs(denom) > 1e-12) {
          t <- cross2(a - p, e) / denom
          out <- rbind(out, p + t * d)
        }
      }
    }
    if (nrow(out) == 0) break
  }
  out
}

ts <- 0.30; gp <- 0.04
total <- 5 * ts + 4 * gp
x_left0 <- -total / 2
y_top0 <- -0.27
for (jx in 0:4) for (jy in 0:4) {
  xa <- x_left0 + jx * (ts + gp)
  ya <- y_top0 - jy * (ts + gp)
  rect_poly <- rbind(
    c(xa, ya), c(xa + ts, ya), c(xa + ts, ya - ts), c(xa, ya - ts)
  )
  clipped <- .clip_convex(rect_poly, v)
  if (nrow(clipped) < 3) next
  alpha <- max(0.07, 0.30 - 0.06 * jy - 0.02 * jx)
  polygon(clipped[, 1], clipped[, 2],
          col = adjustcolor("#9FE3D0", alpha.f = alpha),
          border = adjustcolor("#9FE3D0", alpha.f = alpha * 1.5),
          lwd = 2)
}

# ---------- 文本 ----------
text(0, 0.64, "GLASS", cex = 4.6, font = 2, family = "sans", col = "#FFFFFF")
text(0, 0.47, "Land Surface Satellite", cex = 1.5, font = 1, col = "#9FD8E8")

# 包名:单行粗斜体,直接叠在瓦片上,宽度自适应六边形
nm <- "glass.sqdaitools"
cex_n <- 2.6
while (strwidth(nm, cex = cex_n, font = 4) > 1.54) cex_n <- cex_n - 0.05
text(0, -0.425, nm, cex = cex_n, font = 4, col = "#FFFFFF")

# ---------- 外边框 ----------
polygon(vx, vy, border = "#8FD3E8", lwd = 16)
polygon(vx, vy, border = "#0A2238", lwd = 4)

dev.off()
par(op)
cat("logo written: man/figures/logo.png\n")
