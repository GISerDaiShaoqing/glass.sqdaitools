# pkgdown 站点重建包装(本机唯一入口;dev/ 不随 tarball 发布)
#
# 1) build_site 默认子进程在本机偶发段错误(2026-11,见 AGENTS.md),
#    固定 new_process = FALSE;
# 2) 构建后把 docs/ 下四个许可页(LICENSE{,-text}.{html,md})重写为纯 MIT
#    正文。原因:pkgdown 模板页(HTML 或重排/桩文本)中任何一个无法被
#    GitHub 的许可证检测(licensee)匹配成 MIT,就会产生 'other' 候选;
#    与 LICENSE.md 的 MIT 并存 → 多候选 → 仓库徽章显示 "Other"
#    (2026-11 实测:只重写 .html 两个,残留的 .md 页仍判 other)。
#    纯全文后全部 Exact 匹配为 MIT,候选唯一,徽章恢复 MIT,侧边栏
#    "Full license" 链接保持有效。构建后勿再手改这四个文件。
# 运行: Rscript dev/build_site.R

pkgdown::build_site(preview = FALSE, quiet = TRUE, new_process = FALSE)

mit <- readLines("LICENSE.md", warn = FALSE)
for (f in file.path("docs", c("LICENSE.html", "LICENSE-text.html",
                              "LICENSE.md", "LICENSE-text.md"))) {
  if (file.exists(f)) {
    con <- file(f, open = "wb")   # 二进制写,固定 LF 行尾
    writeLines(mit, con, sep = "\n", useBytes = TRUE)
    close(con)
  }
}
cat("site OK (LICENSE pages normalized to MIT text)\n")
