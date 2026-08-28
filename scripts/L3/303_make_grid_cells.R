## Create grid for random effects structure:
## -- note: you must run twice to specify the grid size (just comment code in/out)

library(sf)
library(dplyr)
library(data.table)
library(tidyverse)
library(here)
here::i_am("scripts/L3/303_make_grid_cells.R")

# Read in data
diurn_on <- readRDS(
  here("data", "L3", "302_evaluate_stations", "302a_diurn_on_data.rds")
)
diurn_ev <- readRDS(
  here("data", "L3", "302_evaluate_stations", "302b_diurn_ev_data.rds")
)
noc <- readRDS(
  here("data", "L3", "302_evaluate_stations", "302c_noc_data.rds")
)


#Bounding box:
bounding_box <- sf::st_bbox(
  c(xmin = -180, ymin = -90, xmax = 180, ymax = 90),
  crs = sf::st_crs(4326)
)


#Create a global polygon grid with cell_size spacing of 0.5 deg
#NOTE: Group by grid_id and see how many station_ids fall into each.

# Grid size 0.5 degrees
global_grid_05 <- sf::st_make_grid(
  sf::st_as_sfc(bounding_box),
  cellsize = c(0.5, 0.5),
  crs = sf::st_crs(4326),
  what = "polygons"
)

### Grid size 5 degrees
# global_grid_50 <- sf::st_make_grid(
#   sf::st_as_sfc(bounding_box),
#   cellsize = c(5, 5),
#   crs = sf::st_crs(4326),
#   what = "polygons"
# )

grid_sf <- sf::st_sf(geometry = global_grid_05) #0.5 degrees
# grid_sf <- sf::st_sf(geometry = global_grid_50) # 5 degrees

#Add grid ID:
grid_sf$grid_ID <- 1:nrow(grid_sf)


## Pull out location data:
diurn_on_loc <- diurn_on |>
  dplyr::select(station_id, latitude, longitude) |>
  dplyr::distinct() #4621 stations

diurn_ev_loc <- diurn_ev |>
  dplyr::select(station_id, latitude, longitude) |>
  dplyr::distinct() #4627 stations

noc_loc <- noc |>
  dplyr::select(station_id, latitude, longitude) |>
  dplyr::distinct() #2869 stations


#Create sf objects:
diurn_on_loc_sf <- diurn_on_loc |>
  sf::st_as_sf(coords = c('longitude', 'latitude'), crs = 4326)

diurn_ev_loc_sf <- diurn_ev_loc |>
  sf::st_as_sf(coords = c('longitude', 'latitude'), crs = 4326)

noc_loc_sf <- noc_loc |>
  sf::st_as_sf(coords = c('longitude', 'latitude'), crs = 4326)


#Determine which grid cell (grid_ID) each station (loc_ID) falls within:
diurn_on_grid <- sf::st_join(diurn_on_loc_sf, grid_sf, join = st_within) |>
  sf::st_drop_geometry() |>
  dplyr::distinct(station_id, .keep_all = TRUE) # Ensures 1 row per station

diurn_ev_grid <- sf::st_join(diurn_ev_loc_sf, grid_sf, join = st_within) |>
  sf::st_drop_geometry() |>
  dplyr::distinct(station_id, .keep_all = TRUE) # Ensures 1 row per station

noc_grid <- sf::st_join(noc_loc_sf, grid_sf, join = st_within) |>
  sf::st_drop_geometry()

#Join information back to dataframe:
diurn_on_info <- diurn_on |>
  dplyr::left_join(diurn_on_grid)

diurn_ev_info <- diurn_ev |>
  dplyr::left_join(diurn_ev_grid)

noc_info <- noc |>
  dplyr::left_join(noc_grid)


### Create the random effect group (add a grouping variable for sp/site/week) to
### datasets, based on the grid_ID location.

## Diurnal onset:
setDT(diurn_on_info)
#Create grouping variable:
diurn_on_final <- diurn_on_info[,
  sp_grid_wk := .GRP,
  .(species_id, grid_ID, week)
]


## Diurnal cessation:
setDT(diurn_ev_info)
#Create grouping variable:
diurn_ev_final <- diurn_ev_info[,
  sp_grid_wk := .GRP,
  .(species_id, grid_ID, week)
]


## Nocturnal:

#Nocturnal dataset needs a 'week' column. Add:
noc_final <- noc_info |>
  dplyr::mutate(week = lubridate::week(night_start))
setDT(noc_final)
#Create grouping variable:
noc_final[, sp_grid_wk := .GRP, .(species_id, grid_ID, week)]


### Check number of stations per grid cell, to see if we should adjust the grid
### cell size (want more than 1 station per cell, ideally).

noc_n_grid <- noc_final |>
  dplyr::select(grid_ID, station_id) |>
  dplyr::group_by(grid_ID) |>
  dplyr::summarise(num = n()) # all with more than 1

di_on_n_grid <- diurn_on_final |>
  dplyr::select(grid_ID, station_id) |>
  dplyr::group_by(grid_ID) |>
  dplyr::summarise(num = n()) # ~7 with only 1

diurn_ev_n_grid <- diurn_ev_final |>
  dplyr::select(grid_ID, station_id) |>
  dplyr::group_by(grid_ID) |>
  dplyr::summarise(num = n()) # ~8 with only 1


### Convert diurnal variables from minutes to hours for onset/cessation:

## Convert time variables from minutes to hours (only in diurnal):
diurn_on_final$first_onset <- (diurn_on_final$first_onset / 60)

diurn_ev_final$ev_ces <- (diurn_ev_final$ev_ces / 60)


### Save out final datasets, with all features and variables.

# ## Diurnal:
# fwrite(diurn_on_final, "Data/Final/diurn_on_final.csv", row.names = FALSE)
# fwrite(diurn_ev_final, "Data/Final/diurn_ev_final.csv", row.names = FALSE)

# ## Nocturnal:
# fwrite(noc_final, "Data/Final/noc_final.csv", row.names = FALSE)

#### 0.5 degree grid cells
saveRDS(
  diurn_on_final,
  file = here("data", "L3", "303_grid_cells", "303a_diurn_on_final_05.rds")
)
saveRDS(
  diurn_ev_final,
  file = here("data", "L3", "303_grid_cells", "303b_diurn_ev_final_05.rds")
)
saveRDS(
  noc_final,
  file = here("data", "L3", "303_grid_cells", "303c_noc_final_05.rds")
)

# ### 5 degree grid cells
# saveRDS(
#   diurn_on_final,
#   file = here("data", "L3", "303_grid_cells", "303d_diurn_on_final_50.rds")
# )
# saveRDS(
#   diurn_ev_final,
#   file = here("data", "L3", "303_grid_cells", "303e_diurn_ev_final_50.rds")
# )
# saveRDS(
#   noc_final,
#   file = here("data", "L3", "303_grid_cells", "303f_noc_final_50.rds")
# )
