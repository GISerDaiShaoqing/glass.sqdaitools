# 包内数据读取 helper
#
# 本机安装实测发现:某些 R 构建下 lazy-load 数据库在命名空间符号解析时
# (函数体内裸引用 `glass_products`)会解析失败(object not found),但
# lazydata 注册环境里的对象本身可正常解码,`data()` 兜底亦总是可用。
# 因此包内代码统一经本 helper 取数据:优先读已解码缓存 ->
# lazydata 注册环境(data/wildfly rdb 解码) -> `data()` 显式加载。
.glass_data_cache <- new.env(parent = emptyenv())

.read_pkg_data <- function(name) {
  v <- get0(name, envir = .glass_data_cache, inherits = FALSE)
  if (is.null(v)) {
    ns <- asNamespace("glass.sqdaitools")
    v <- get0(name, envir = getNamespaceInfo(ns, "lazydata"), inherits = FALSE)
    if (is.null(v)) {
      e <- new.env(parent = emptyenv())
      utils::data(list = name, package = "glass.sqdaitools", envir = e)
      v <- get(name, envir = e, inherits = FALSE)
    }
    assign(name, v, envir = .glass_data_cache)
  }
  v
}
