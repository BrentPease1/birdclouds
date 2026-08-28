### Filter the grid cells to only include those
### with certain # by the quantile from 300_analyze_models.R

library(tidyverse)
library(here)
here::i_am("scripts/L3/304_filter_grid_data_final.R")

#### 0.5 degree grid datasets

diurn_on_final <- readRDS(
  here("data", "L3", "303_grid_cells", "303a_diurn_on_final_05.rds")
)
diurn_ev_final <- readRDS(
  here("data", "L3", "303_grid_cells", "303b_diurn_ev_final_05.rds")
)
noc_final <- readRDS(
  here("data", "L3", "303_grid_cells", "303c_noc_final_05.rds")
)

### save unfiltered 0.5 degree dataset
saveRDS(
  diurn_on_final,
  file = here(
    "data",
    "L3",
    "304_final_data",
    "304_diurn_on_final_05_no_filter.rds"
  )
)


### 5.0 degree datasets

diurn_on_final <- readRDS(
  here("data", "L3", "303_grid_cells", "303d_diurn_on_final_50.rds")
)
diurn_ev_final <- readRDS(
  here("data", "L3", "303_grid_cells", "303e_diurn_ev_final_50.rds")
)
noc_final <- readRDS(
  here("data", "L3", "303_grid_cells", "303f_noc_final_50.rds")
)

### save unfiltered 5.0 degree dataset
saveRDS(
  diurn_on_final,
  file = here(
    "data",
    "L3",
    "304_final_data",
    "304_diurn_on_final_50_no_filter.rds"
  )
)


##########################################
### Process onset diurnal dataset ########
##########################################

## Get num. stations and num. vocs per grid cell
a <- diurn_on_final |>
  dplyr::group_by(grid_ID) |>
  dplyr::summarize(
    num_vocs = dplyr::n(), # Total vocs
    num_stats = dplyr::n_distinct(station_id), # Total unique stations
    .groups = "drop"
  )

#quantile(a$num_vocs, probs = seq(0, 1, 0.1))

## Grab grid cells in the bottom 10% (<= 18 vocalizations)
bottom_10_grid_ids <- a |>
  dplyr::filter(num_vocs <= 18) |>
  dplyr::pull(grid_ID)

## Filter main dataset to exclude bottom 10% grid cells
diurn_on_filtered <- diurn_on_final |>
  dplyr::filter(!grid_ID %in% bottom_10_grid_ids)


## Print data loss summary
cat("Original rows:", nrow(diurn_on_final))
cat("\nFiltered rows:", nrow(diurn_on_filtered))
cat("\nRows dropped :", nrow(diurn_on_final) - nrow(diurn_on_filtered))
cat("\nUnique grids left:", length(unique(diurn_on_filtered$grid_ID)))

rm(a, bottom_10_grid_ids, diurn_on_final)


##########################################
### Process cessation diurnal dataset ####
##########################################

## Get num. stations and num. vocs per grid cell
b <- diurn_ev_final |>
  dplyr::group_by(grid_ID) |>
  dplyr::summarize(
    num_vocs = dplyr::n(), # Total vocs
    num_stats = dplyr::n_distinct(station_id), # Total unique stations
    .groups = "drop"
  )

## Grab grid cells in the bottom 10% (<= 18 vocalizations)
bottom_10_grid_ids <- b |>
  dplyr::filter(num_vocs <= 18) |>
  dplyr::pull(grid_ID)

## Filter main dataset to exclude bottom 10% grid cells
diurn_ev_filtered <- diurn_ev_final |>
  dplyr::filter(!grid_ID %in% bottom_10_grid_ids)

## Print data loss summary
cat("Original rows:", nrow(diurn_ev_final))
cat("\nFiltered rows:", nrow(diurn_ev_filtered))
cat("\nRows dropped :", nrow(diurn_ev_final) - nrow(diurn_ev_filtered))
cat("\nUnique grids left:", length(unique(diurn_ev_filtered$grid_ID)))

rm(b, bottom_10_grid_ids, diurn_ev_final)

##########################################
### Process nocturnal dataset ############
##########################################

## Nocturnal dataset doesn't need a filter to converge
noc_filtered <- noc_final
rm(noc_final)

##########################################
### Save 0.5 degree filtered datasets ####
##########################################

saveRDS(
  diurn_on_filtered,
  file = here("data", "L3", "304_final_data", "304a_diurn_on_final_05.rds")
)
saveRDS(
  diurn_ev_filtered,
  file = here("data", "L3", "304_final_data", "304b_diurn_ev_final_05.rds")
)
saveRDS(
  noc_filtered,
  file = here("data", "L3", "304_final_data", "305c_noc_final_05.rds")
)

rm(diurn_on_filtered, diurn_ev_filtered, noc_filtered)


##########################################
### Save 5.0 degree filtered datasets ####
##########################################

saveRDS(
  diurn_on_filtered,
  file = here("data", "L3", "304_final_data", "304d_diurn_on_final_50.rds")
)
saveRDS(
  diurn_ev_filtered,
  file = here("data", "L3", "304_final_data", "304e_diurn_ev_final_50.rds")
)
saveRDS(
  noc_filtered,
  file = here("data", "L3", "304_final_data", "304f_noc_final_50.rds")
)

rm(diurn_on_filtered, diurn_ev_filtered, noc_filtered)
