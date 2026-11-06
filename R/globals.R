# LazyData 数据集在函数体内被引用,需要声明给 R CMD check
utils::globalVariables(c("glass_products", "glass_tiles"))
