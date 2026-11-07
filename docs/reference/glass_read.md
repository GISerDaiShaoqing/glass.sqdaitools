# Read GLASS HDF granules with fill/scale handling

Wraps
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
for GLASS HDF-EOS granules and applies product-level band cleanup in one
step:

1.  raw fill values (e.g. 255) set to `NA`,

2.  the stored scale factor multiplied in,

3.  values outside the valid scaled range set to `NA`.

When `product` names a registered variant, `fill`, `scale_factor` and
`valid_range` default to the registry values
([glass_products](https://gisersqdai.top/glass.sqdaitools/reference/glass_products.md));
explicit arguments override the registry.

## Usage

``` r
glass_read(
  input,
  product = NULL,
  fill = NULL,
  scale_factor = NULL,
  valid_range = NULL,
  subds = NULL,
  ...
)
```

## Arguments

- input:

  One or more file paths of the **same variant and tile** (they become
  temporal layers of a multi-layer `SpatRaster`), or an already-open
  `SpatRaster`.

- product:

  Optional registry variant key, e.g. `"LAI_MODIS_250M"`.

- fill:

  Optional raw fill value (overrides the registry value).

- scale_factor:

  Optional scale factor.

- valid_range:

  Optional `c(min, max)` of the scaled data.

- subds:

  Optional sub-dataset selection passed to
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  (needed for multi-band products such as `Ta`).

- ...:

  Passed on to
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html).

## Value

A cleaned `SpatRaster` in data units.

## Examples

``` r
if (FALSE) { # \dontrun{
r <- glass_read("GLASS01D01.V60.A2018217.h28v05.2022013.hdf",
                product = "LAI_MODIS_250M")
} # }
```
