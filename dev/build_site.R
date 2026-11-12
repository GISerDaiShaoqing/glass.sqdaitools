# pkgdown 站点重建包装(本机唯一入口;dev/ 不随 tarball 发布)
#
# 1) build_site 默认子进程在本机偶发段错误(2026-11,见 AGENTS.md),
#    固定 new_process = FALSE;
# 2) 构建后把 docs/LICENSE.html 与 docs/LICENSE-text.html 重写为纯 MIT 正文。
#    原因:这两个 pkgdown 模板页若保持 HTML 形态,GitHub 的许可证检测
#    (licensee)对它们的 Dice 相似度不足,判为 'other';与 LICENSE.md 的
#    MIT 并存即触发多候选 → 仓库徽章显示 "Other"(2026-11 实测)。
#    纯文本后两页被 Exact 匹配为 MIT,候选唯一,徽章恢复 MIT,侧边栏
#    "Full license" 链接保持有效。构建后勿再手改这两个文件。
# 运行: Rscript dev/build_site.R

pkgdown::build_site(preview = FALSE, quiet = TRUE, new_process = FALSE)

mit <- readLines("LICENSE.md", warn = FALSE)
for (f in c("docs/LICENSE.html", "docs/LICENSE-text.html")) {
  if (file.exists(f)) {
    con <- file(f, open = "wb")   # 二进制写,固定 LF 行尾
    writeLines(mit, con, sep = "\n", useBytes = TRUE)
    close(con)
  }
}
cat("site OK (LICENSE pages normalized to MIT text)\n")
