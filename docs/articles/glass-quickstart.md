# Getting started with glass.sqdaitools

``` r
library(glass.sqdaitools)
```

This vignette walks through the GLASS data lifecycle covered by the
package: registry lookups, tile mapping, DOY folders, downloading and
post-processing. Dataset-bound chunks run offline; anything that touches
the network is shown with `eval = FALSE` so the vignette builds without
connectivity.

## The product registry

The registry has one row per archive variant (product x source x
resolution) observed under <https://glass.hku.hk/archive/>:

``` r
glass_registry(verified_only = TRUE)[, c("variant_id", "res", "cadence_days",
                                         "observed_years", "url_root")]
#>                                           variant_id                   res
#> 1                                      AGB_0.01D_V02                   V02
#> 2                                          AGB_0.05D                  <NA>
#> 3                                      AGB_0.05D_old                  <NA>
#> 4                                        AGB_1KM_V01                   V01
#> 5                                   Albedo_ABI_0_05D                 0.05D
#> 6                                    Albedo_ABI_0_5D                  0.5D
#> 7                                    Albedo_ABI_500M                  500M
#> 8                   Albedo_ABI_landcover_climatology landcover_climatology
#> 9                                  Albedo_AVHRR_0_5D                  0.5D
#> 10                                  Albedo_MIX_0_05D                 0.05D
#> 11                                   Albedo_MIX_0_5D                  0.5D
#> 12                                 Albedo_MODIS_0_5D                  0.5D
#> 13                                 Albedo_MODIS_250M                  250M
#> 14                                 Albedo_MODIS_500M                  500M
#> 15                                  AWGF_LST_ABI_2km                   2km
#> 16                           AWGF_LST_ABI_CMG_002deg            CMG_002deg
#> 17                           AWGF_LST_ABI_CMG_005deg            CMG_005deg
#> 18                                  AWGF_LST_GHA-LST                  <NA>
#> 19                                   BBE_AVHRR_0_05D                 0.05D
#> 20                                    BBE_AVHRR_0_1D                  0.1D
#> 21                                    BBE_AVHRR_0_5D                  0.5D
#> 22                                   BBE_MODIS_0_05D                 0.05D
#> 23                                    BBE_MODIS_0_5D                  0.5D
#> 24                                     BBE_MODIS_1KM                   1KM
#> 25                                    BBE_MODIS_500M                  500M
#> 26                               Crops_PADDYCALENDAR                  <NA>
#> 27                              Crops_PADDYINTENSITY                  <NA>
#> 28                          Crops_PADDYINTERCROPPING                  <NA>
#> 29                                   DSR_AVHRR_0_05D                 0.05D
#> 30                                   DSR_MODIS_0_05D                 0.05D
#> 31                                    DSR_MODIS_0_5D                  0.5D
#> 32                                    DSR_MODIS_Topo                  <NA>
#> 33                                     EDD_MODIS_1KM                   1KM
#> 34                                    ET_AVHRR_0_05D                 0.05D
#> 35                                     ET_AVHRR_0_5D                  0.5D
#> 36                                    ET_MODIS_0_05D                 0.05D
#> 37                                     ET_MODIS_0_5D                  0.5D
#> 38                                      ET_MODIS_1KM                   1KM
#> 39                                    EVI_MODIS_0_05                  0.05
#> 40                                     EVI_MODIS_0_1                   0.1
#> 41                                    EVI_MODIS_0_25                  0.25
#> 42                                    EVI_MODIS_250M                  250M
#> 43                                 FAPAR_AVHRR_0_05D                 0.05D
#> 44                                FAPAR_HR_FAPAR_V01                   V01
#> 45                                 FAPAR_MODIS_0_05D                 0.05D
#> 46                                  FAPAR_MODIS_0_1D                  0.1D
#> 47                                 FAPAR_MODIS_0_25D                 0.25D
#> 48                                  FAPAR_MODIS_0_5D                  0.5D
#> 49                                  FAPAR_MODIS_250M                  250M
#> 50                                  FAPAR_MODIS_500M                  500M
#> 51                                    FFC_MODIS_250M                  250M
#> 52                                   FVC_AVHRR_0_05D                 0.05D
#> 53                                    FVC_AVHRR_0_5D                  0.5D
#> 54                             FVC_AVHRR_0_5D_netCDF           0.5D_netCDF
#> 55                                   FVC_MODIS_0_05D                 0.05D
#> 56                                    FVC_MODIS_0_5D                  0.5D
#> 57                             FVC_MODIS_0_5D_netCDF           0.5D_netCDF
#> 58                                    FVC_MODIS_500M                  500M
#> 59                                   GPP_AVHRR_0_05D                 0.05D
#> 60                                    GPP_AVHRR_0_5D                  0.5D
#> 61                                    GPP_MODIS_500M                  500M
#> 62              KGClim_KGClim_V1_future_rcp2_6_2030s          rcp2_6_2030s
#> 63              KGClim_KGClim_V1_future_rcp2_6_2050s          rcp2_6_2050s
#> 64              KGClim_KGClim_V1_future_rcp2_6_2070s          rcp2_6_2070s
#> 65              KGClim_KGClim_V1_future_rcp2_6_2080s          rcp2_6_2080s
#> 66              KGClim_KGClim_V1_future_rcp4_5_2030s          rcp4_5_2030s
#> 67              KGClim_KGClim_V1_future_rcp4_5_2050s          rcp4_5_2050s
#> 68              KGClim_KGClim_V1_future_rcp4_5_2070s          rcp4_5_2070s
#> 69              KGClim_KGClim_V1_future_rcp4_5_2080s          rcp4_5_2080s
#> 70              KGClim_KGClim_V1_future_rcp6_0_2030s          rcp6_0_2030s
#> 71              KGClim_KGClim_V1_future_rcp6_0_2050s          rcp6_0_2050s
#> 72              KGClim_KGClim_V1_future_rcp6_0_2070s          rcp6_0_2070s
#> 73              KGClim_KGClim_V1_future_rcp6_0_2080s          rcp6_0_2080s
#> 74              KGClim_KGClim_V1_future_rcp8_5_2030s          rcp8_5_2030s
#> 75              KGClim_KGClim_V1_future_rcp8_5_2050s          rcp8_5_2050s
#> 76              KGClim_KGClim_V1_future_rcp8_5_2070s          rcp8_5_2070s
#> 77              KGClim_KGClim_V1_future_rcp8_5_2080s          rcp8_5_2080s
#> 78  KGClim_KGClim_V1_future_model_rcp2_6_2030s_model    rcp2_6_2030s_model
#> 79  KGClim_KGClim_V1_future_model_rcp2_6_2050s_model    rcp2_6_2050s_model
#> 80  KGClim_KGClim_V1_future_model_rcp2_6_2070s_model    rcp2_6_2070s_model
#> 81  KGClim_KGClim_V1_future_model_rcp2_6_2080s_model    rcp2_6_2080s_model
#> 82  KGClim_KGClim_V1_future_model_rcp4_5_2030s_model    rcp4_5_2030s_model
#> 83  KGClim_KGClim_V1_future_model_rcp4_5_2050s_model    rcp4_5_2050s_model
#> 84  KGClim_KGClim_V1_future_model_rcp4_5_2070s_model    rcp4_5_2070s_model
#> 85  KGClim_KGClim_V1_future_model_rcp4_5_2080s_model    rcp4_5_2080s_model
#> 86  KGClim_KGClim_V1_future_model_rcp6_0_2030s_model    rcp6_0_2030s_model
#> 87  KGClim_KGClim_V1_future_model_rcp6_0_2050s_model    rcp6_0_2050s_model
#> 88  KGClim_KGClim_V1_future_model_rcp6_0_2070s_model    rcp6_0_2070s_model
#> 89  KGClim_KGClim_V1_future_model_rcp6_0_2080s_model    rcp6_0_2080s_model
#> 90  KGClim_KGClim_V1_future_model_rcp8_5_2030s_model    rcp8_5_2030s_model
#> 91  KGClim_KGClim_V1_future_model_rcp8_5_2050s_model    rcp8_5_2050s_model
#> 92  KGClim_KGClim_V1_future_model_rcp8_5_2070s_model    rcp8_5_2070s_model
#> 93  KGClim_KGClim_V1_future_model_rcp8_5_2080s_model    rcp8_5_2080s_model
#> 94             KGClim_KGClim_V1_historical_1979_2008             1979_2008
#> 95             KGClim_KGClim_V1_historical_1980_2009             1980_2009
#> 96             KGClim_KGClim_V1_historical_1981_2010             1981_2010
#> 97             KGClim_KGClim_V1_historical_1982_2011             1982_2011
#> 98             KGClim_KGClim_V1_historical_1983_2012             1983_2012
#> 99             KGClim_KGClim_V1_historical_1984_2013             1984_2013
#> 100                                        LAI_AVHRR                  <NA>
#> 101                                   LAI_HR_LAI_V01                   V01
#> 102                                  LAI_MODIS_0_05D                 0.05D
#> 103                                   LAI_MODIS_0_1D                  0.1D
#> 104                                  LAI_MODIS_0_25D                 0.25D
#> 105                                   LAI_MODIS_0_5D                  0.5D
#> 106                                   LAI_MODIS_250M                  250M
#> 107                                   LAI_MODIS_500M                  500M
#> 108                                  LST_AVHRR_0_05D                 0.05D
#> 109                                    LST_AVHRR_05D                   05D
#> 110                              LST_AVHRR_Daily-ODC             Daily-ODC
#> 111                                  LST_MODIS_Daily                 Daily
#> 112                                    LST_MODIS_Ins                   Ins
#> 113                                       LWRT_AVHRR                  <NA>
#> 115                              LWRT_MODIS_InS_0_5D              InS_0.5D
#> 116                                  NDVI_MODIS_0_05                  0.05
#> 117                                   NDVI_MODIS_0_1                   0.1
#> 118                                  NDVI_MODIS_0_25                  0.25
#> 119                                  NDVI_MODIS_250M                  250M
#> 120                                  NPP_AVHRR_0_05D                 0.05D
#> 121                                   NPP_AVHRR_0_5D                  0.5D
#> 122                                   NPP_MODIS_500M                  500M
#> 123                                  PAR_MODIS_0_05D                 0.05D
#> 124                                   PAR_MODIS_0_5D                  0.5D
#> 125                                         RN_AVHRR                  <NA>
#> 126                                         RN_MODIS                  <NA>
#> 128                                         SM_AVHRR                  <NA>
#> 129                                         SM_MODIS                  <NA>
#> 130                                    SRF_MODIS_1KM                   1KM
#> 131                                         Ta_MODIS                  <NA>
#> 132                                      TPSCE_AVHRR                  <NA>
#> 133                                        Tsa_MODIS                  <NA>
#>     cadence_days observed_years
#> 1             NA           <NA>
#> 2             NA           <NA>
#> 3             NA           <NA>
#> 4             NA           <NA>
#> 5             NA           <NA>
#> 6             NA           <NA>
#> 7             NA           <NA>
#> 8             NA           <NA>
#> 9             NA      1981-2023
#> 10            NA      1981-2024
#> 11            NA      1981-2021
#> 12            NA      2000-2023
#> 13             4      2000-2024
#> 14             4      2000-2024
#> 15             1      2017-2021
#> 16             1      2017-2021
#> 17             1      2017-2021
#> 18            NA      2011-2025
#> 19            NA      1981-2022
#> 20             1      1980-2020
#> 21            NA      1981-2022
#> 22            NA      2000-2022
#> 23            NA      2000-2022
#> 24             1      2000-2022
#> 25             1      2018-2022
#> 26            NA           <NA>
#> 27            NA           <NA>
#> 28            NA           <NA>
#> 29            NA      1981-2018
#> 30            NA      2000-2025
#> 31            NA      2000-2024
#> 32            NA      2003-2024
#> 33             1      2005-2022
#> 34            NA      1981-2022
#> 35            NA      1981-2022
#> 36            NA      2000-2024
#> 37            NA      2000-2021
#> 38             8      2000-2024
#> 39            NA      2000-2025
#> 40            NA      2000-2021
#> 41            NA      2000-2021
#> 42             8      2000-2025
#> 43            NA      1982-2018
#> 44            NA           <NA>
#> 45            NA      2000-2025
#> 46            NA      2000-2025
#> 47            NA      2000-2025
#> 48            NA      2000-2025
#> 49             8      2000-2025
#> 50             8      2000-2025
#> 51             8      2000-2024
#> 52            NA      1981-2020
#> 53            NA      1981-2020
#> 54            NA      1982-2018
#> 55            NA      2000-2024
#> 56            NA      2000-2024
#> 57            NA      2000-2019
#> 58             8      2000-2024
#> 59            NA      1981-2018
#> 60            NA      1982-2018
#> 61             8      2000-2025
#> 62            NA           <NA>
#> 63            NA           <NA>
#> 64            NA           <NA>
#> 65            NA           <NA>
#> 66            NA           <NA>
#> 67            NA           <NA>
#> 68            NA           <NA>
#> 69            NA           <NA>
#> 70            NA           <NA>
#> 71            NA           <NA>
#> 72            NA           <NA>
#> 73            NA           <NA>
#> 74            NA           <NA>
#> 75            NA           <NA>
#> 76            NA           <NA>
#> 77            NA           <NA>
#> 78            NA           <NA>
#> 79            NA           <NA>
#> 80            NA           <NA>
#> 81            NA           <NA>
#> 82            NA           <NA>
#> 83            NA           <NA>
#> 84            NA           <NA>
#> 85            NA           <NA>
#> 86            NA           <NA>
#> 87            NA           <NA>
#> 88            NA           <NA>
#> 89            NA           <NA>
#> 90            NA           <NA>
#> 91            NA           <NA>
#> 92            NA           <NA>
#> 93            NA           <NA>
#> 94            NA           <NA>
#> 95            NA           <NA>
#> 96            NA           <NA>
#> 97            NA           <NA>
#> 98            NA           <NA>
#> 99            NA           <NA>
#> 100           NA      1981-2018
#> 101           NA           <NA>
#> 102           NA      2000-2025
#> 103           NA      2000-2025
#> 104           NA      2000-2025
#> 105           NA      2000-2025
#> 106            8      2000-2025
#> 107            8      2000-2025
#> 108           NA      1982-2024
#> 109           NA      1981-2000
#> 110           NA      1981-2000
#> 111            1      2000-2020
#> 112            1      2002-2020
#> 113           NA      1981-2021
#> 115            1      2002-2018
#> 116           NA      2000-2025
#> 117           NA      2000-2021
#> 118           NA      2000-2021
#> 119            8      2000-2025
#> 120           NA      1981-2018
#> 121           NA      1982-2018
#> 122            8      2000-2025
#> 123           NA      2000-2025
#> 124           NA      2000-2024
#> 125           NA      1981-2018
#> 126           NA      2000-2024
#> 128           NA      1982-2021
#> 129            1      2000-2020
#> 130            1      2000-2023
#> 131            1      2000-2020
#> 132           NA      1981-2016
#> 133            1      2000-2020
#>                                                                           url_root
#> 1                                      https://glass.hku.hk/archive/AGB/0.01D/V02/
#> 2                                          https://glass.hku.hk/archive/AGB/0.05D/
#> 3                                      https://glass.hku.hk/archive/AGB/0.05D_old/
#> 4                                        https://glass.hku.hk/archive/AGB/1KM/V01/
#> 5                                   https://glass.hku.hk/archive/Albedo/ABI/0.05D/
#> 6                                    https://glass.hku.hk/archive/Albedo/ABI/0.5D/
#> 7                                    https://glass.hku.hk/archive/Albedo/ABI/500M/
#> 8                   https://glass.hku.hk/archive/Albedo/ABI/landcover_climatology/
#> 9                                  https://glass.hku.hk/archive/Albedo/AVHRR/0.5D/
#> 10                                  https://glass.hku.hk/archive/Albedo/MIX/0.05D/
#> 11                                   https://glass.hku.hk/archive/Albedo/MIX/0.5D/
#> 12                                 https://glass.hku.hk/archive/Albedo/MODIS/0.5D/
#> 13                                 https://glass.hku.hk/archive/Albedo/MODIS/250M/
#> 14                                 https://glass.hku.hk/archive/Albedo/MODIS/500M/
#> 15                                  https://glass.hku.hk/archive/AWGF_LST/ABI/2km/
#> 16                           https://glass.hku.hk/archive/AWGF_LST/ABI/CMG_002deg/
#> 17                           https://glass.hku.hk/archive/AWGF_LST/ABI/CMG_005deg/
#> 18                                  https://glass.hku.hk/archive/AWGF_LST/GHA-LST/
#> 19                                   https://glass.hku.hk/archive/BBE/AVHRR/0.05D/
#> 20                                    https://glass.hku.hk/archive/BBE/AVHRR/0.1D/
#> 21                                    https://glass.hku.hk/archive/BBE/AVHRR/0.5D/
#> 22                                   https://glass.hku.hk/archive/BBE/MODIS/0.05D/
#> 23                                    https://glass.hku.hk/archive/BBE/MODIS/0.5D/
#> 24                                     https://glass.hku.hk/archive/BBE/MODIS/1KM/
#> 25                                    https://glass.hku.hk/archive/BBE/MODIS/500M/
#> 26                               https://glass.hku.hk/archive/Crops/PADDYCALENDAR/
#> 27                              https://glass.hku.hk/archive/Crops/PADDYINTENSITY/
#> 28                          https://glass.hku.hk/archive/Crops/PADDYINTERCROPPING/
#> 29                                   https://glass.hku.hk/archive/DSR/AVHRR/0.05D/
#> 30                                   https://glass.hku.hk/archive/DSR/MODIS/0.05D/
#> 31                                    https://glass.hku.hk/archive/DSR/MODIS/0.5D/
#> 32                                    https://glass.hku.hk/archive/DSR/MODIS_Topo/
#> 33                                     https://glass.hku.hk/archive/EDD/MODIS/1KM/
#> 34                                    https://glass.hku.hk/archive/ET/AVHRR/0.05D/
#> 35                                     https://glass.hku.hk/archive/ET/AVHRR/0.5D/
#> 36                                    https://glass.hku.hk/archive/ET/MODIS/0.05D/
#> 37                                     https://glass.hku.hk/archive/ET/MODIS/0.5D/
#> 38                                      https://glass.hku.hk/archive/ET/MODIS/1KM/
#> 39                                    https://glass.hku.hk/archive/EVI/MODIS/0.05/
#> 40                                     https://glass.hku.hk/archive/EVI/MODIS/0.1/
#> 41                                    https://glass.hku.hk/archive/EVI/MODIS/0.25/
#> 42                                    https://glass.hku.hk/archive/EVI/MODIS/250M/
#> 43                                 https://glass.hku.hk/archive/FAPAR/AVHRR/0.05D/
#> 44                                https://glass.hku.hk/archive/FAPAR/HR_FAPAR/V01/
#> 45                                 https://glass.hku.hk/archive/FAPAR/MODIS/0.05D/
#> 46                                  https://glass.hku.hk/archive/FAPAR/MODIS/0.1D/
#> 47                                 https://glass.hku.hk/archive/FAPAR/MODIS/0.25D/
#> 48                                  https://glass.hku.hk/archive/FAPAR/MODIS/0.5D/
#> 49                                  https://glass.hku.hk/archive/FAPAR/MODIS/250M/
#> 50                                  https://glass.hku.hk/archive/FAPAR/MODIS/500M/
#> 51                                    https://glass.hku.hk/archive/FFC/MODIS/250M/
#> 52                                   https://glass.hku.hk/archive/FVC/AVHRR/0.05D/
#> 53                                    https://glass.hku.hk/archive/FVC/AVHRR/0.5D/
#> 54                             https://glass.hku.hk/archive/FVC/AVHRR/0.5D_netCDF/
#> 55                                   https://glass.hku.hk/archive/FVC/MODIS/0.05D/
#> 56                                    https://glass.hku.hk/archive/FVC/MODIS/0.5D/
#> 57                             https://glass.hku.hk/archive/FVC/MODIS/0.5D_netCDF/
#> 58                                    https://glass.hku.hk/archive/FVC/MODIS/500M/
#> 59                                   https://glass.hku.hk/archive/GPP/AVHRR/0.05D/
#> 60                                    https://glass.hku.hk/archive/GPP/AVHRR/0.5D/
#> 61                                    https://glass.hku.hk/archive/GPP/MODIS/500M/
#> 62              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp2_6_2030s/
#> 63              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp2_6_2050s/
#> 64              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp2_6_2070s/
#> 65              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp2_6_2080s/
#> 66              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp4_5_2030s/
#> 67              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp4_5_2050s/
#> 68              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp4_5_2070s/
#> 69              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp4_5_2080s/
#> 70              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp6_0_2030s/
#> 71              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp6_0_2050s/
#> 72              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp6_0_2070s/
#> 73              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp6_0_2080s/
#> 74              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp8_5_2030s/
#> 75              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp8_5_2050s/
#> 76              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp8_5_2070s/
#> 77              https://glass.hku.hk/archive/KGClim/KGClim_V1_future/rcp8_5_2080s/
#> 78  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp2_6_2030s_model/
#> 79  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp2_6_2050s_model/
#> 80  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp2_6_2070s_model/
#> 81  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp2_6_2080s_model/
#> 82  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp4_5_2030s_model/
#> 83  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp4_5_2050s_model/
#> 84  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp4_5_2070s_model/
#> 85  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp4_5_2080s_model/
#> 86  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp6_0_2030s_model/
#> 87  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp6_0_2050s_model/
#> 88  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp6_0_2070s_model/
#> 89  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp6_0_2080s_model/
#> 90  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp8_5_2030s_model/
#> 91  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp8_5_2050s_model/
#> 92  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp8_5_2070s_model/
#> 93  https://glass.hku.hk/archive/KGClim/KGClim_V1_future_model/rcp8_5_2080s_model/
#> 94             https://glass.hku.hk/archive/KGClim/KGClim_V1_historical/1979_2008/
#> 95             https://glass.hku.hk/archive/KGClim/KGClim_V1_historical/1980_2009/
#> 96             https://glass.hku.hk/archive/KGClim/KGClim_V1_historical/1981_2010/
#> 97             https://glass.hku.hk/archive/KGClim/KGClim_V1_historical/1982_2011/
#> 98             https://glass.hku.hk/archive/KGClim/KGClim_V1_historical/1983_2012/
#> 99             https://glass.hku.hk/archive/KGClim/KGClim_V1_historical/1984_2013/
#> 100                                        https://glass.hku.hk/archive/LAI/AVHRR/
#> 101                                   https://glass.hku.hk/archive/LAI/HR_LAI/V01/
#> 102                                  https://glass.hku.hk/archive/LAI/MODIS/0.05D/
#> 103                                   https://glass.hku.hk/archive/LAI/MODIS/0.1D/
#> 104                                  https://glass.hku.hk/archive/LAI/MODIS/0.25D/
#> 105                                   https://glass.hku.hk/archive/LAI/MODIS/0.5D/
#> 106                                   https://glass.hku.hk/archive/LAI/MODIS/250M/
#> 107                                   https://glass.hku.hk/archive/LAI/MODIS/500M/
#> 108                                  https://glass.hku.hk/archive/LST/AVHRR/0.05D/
#> 109                                    https://glass.hku.hk/archive/LST/AVHRR/05D/
#> 110                              https://glass.hku.hk/archive/LST/AVHRR/Daily-ODC/
#> 111                              https://glass.hku.hk/archive/LST/MODIS/Daily/1KM/
#> 112                                    https://glass.hku.hk/archive/LST/MODIS/Ins/
#> 113                                       https://glass.hku.hk/archive/LWRT/AVHRR/
#> 115                              https://glass.hku.hk/archive/LWRT/MODIS/InS_0.5D/
#> 116                                  https://glass.hku.hk/archive/NDVI/MODIS/0.05/
#> 117                                   https://glass.hku.hk/archive/NDVI/MODIS/0.1/
#> 118                                  https://glass.hku.hk/archive/NDVI/MODIS/0.25/
#> 119                                  https://glass.hku.hk/archive/NDVI/MODIS/250M/
#> 120                                  https://glass.hku.hk/archive/NPP/AVHRR/0.05D/
#> 121                                   https://glass.hku.hk/archive/NPP/AVHRR/0.5D/
#> 122                                   https://glass.hku.hk/archive/NPP/MODIS/500M/
#> 123                                  https://glass.hku.hk/archive/PAR/MODIS/0.05D/
#> 124                                   https://glass.hku.hk/archive/PAR/MODIS/0.5D/
#> 125                                         https://glass.hku.hk/archive/RN/AVHRR/
#> 126                                         https://glass.hku.hk/archive/RN/MODIS/
#> 128                                         https://glass.hku.hk/archive/SM/AVHRR/
#> 129                                         https://glass.hku.hk/archive/SM/MODIS/
#> 130                                    https://glass.hku.hk/archive/SRF/MODIS/1KM/
#> 131                                         https://glass.hku.hk/archive/Ta/MODIS/
#> 132                                      https://glass.hku.hk/archive/TPSCE/AVHRR/
#> 133                                        https://glass.hku.hk/archive/Tsa/MODIS/
```

Variants with `verified = TRUE` were checked against real granules: file
naming fragments (`code`, `version`, `layer`), year coverage, and band
metadata (`fill_value`, `scale_factor`, `valid_min/valid_max`) all come
from that check and are consumed by
[`glass_read()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_read.md)/[`glass_process()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_process.md).

## From region of interest to tiles

Tiled GLASS products reuse the MODIS sinusoidal `h<v>` grid. Rebuild the
exact tile polygons and see which ones your study area needs:

``` r
# 一个 2-3 km 缓冲的点(上海人民广场周边)
roi <- sf::st_buffer(
  sf::st_sfc(sf::st_point(c(121.47, 31.23)), crs = 4326),
  3000
)
tiles <- glass_tiles_for_sf(roi)
tiles[, c("h", "v", "lon_min", "lon_max", "lat_min", "lat_max", "valid")]
#> Simple feature collection with 1 feature and 7 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 115.4701 ymin: 30 xmax: 143.5948 ymax: 40
#> Geodetic CRS:  WGS 84
#>    h v  lon_min  lon_max lat_min lat_max valid                       geometry
#> 1 28 5 115.4701 143.5948      30      40  TRUE POLYGON ((130.5407 40, 143....
```

For straight bounding boxes there is
[`glass_tiles_for_bbox()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_tiles_for_bbox.md),
and passing the resulting table directly to
[`glass_fetch()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_fetch.md)
is allowed (it understands data frames with `h`/`v` columns).

## Date range to composite folders

The archive stores one folder per composite start day-of-year:

``` r
glass_doys("LAI_MODIS_250M", from = "2018-08-01", to = "2018-08-31")
#> # A tibble: 5 × 4
#>    year   doy date       folder
#>   <int> <int> <date>     <chr> 
#> 1  2018   209 2018-07-28 209   
#> 2  2018   217 2018-08-05 217   
#> 3  2018   225 2018-08-13 225   
#> 4  2018   233 2018-08-21 233   
#> 5  2018   241 2018-08-29 241
```

`mode = "span"` (default) keeps composites partially overlapping the
range; `mode = "start"` keeps only those starting inside it.

## Finding and downloading files

[`glass_list_files()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_list_files.md)
reads one composite folder’s listing;
[`glass_fetch()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_fetch.md)
loops it over the DOY table and downloads with resume/verification:

``` r
files <- glass_fetch(
  "LAI_MODIS_250M",
  from = "2018-08-01", to = "2018-12-31",
  roi = roi,
  out_dir = "data/glass/lai"
)
# 用 dry_run = TRUE 先看清单,不下载
```

The download engine compares sizes with the server, resumes `.part`
files via HTTP `Range`, and writes `glass_manifest.csv` into `out_dir`,
so an interrupted run continues where it stopped.

## Post-processing

[`glass_process()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_process.md)
is the parameterised pipeline: cleanup, mosaic, reproject, mask,
optional temporal collapse:

``` r
mean_lai <- glass_process(
  files,
  roi = roi,
  product = "LAI_MODIS_250M",
  method = "cubic",
  fun = "mean",
  outfile = "glass_lai_mean.tif"
)
```

Band cleanup comes from the registry: the raw fill (e.g. 255) maps to
`NA` after scaling, and the valid scaled range is excluded from
analysis. For an already-read `SpatRaster`,
[`glass_read()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_read.md)
with no `product` is a no-op except for explicit `fill`/`valid_range`
arguments.

## Interactive UI

``` r
glass_app()
```

Draw the ROI on a map, pick a verified variant, preview the manifest and
download — the same package functions underneath. The output folder can
be chosen through the built-in, in-page directory browser (or typed
directly) and a progress bar follows each file during the batch
download.
