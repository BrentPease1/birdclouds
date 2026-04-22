#################################################################################
### Gilbert X Pease Joint Lab Project: Bird-Cloud Analysis
###  - Dirunal Data -
#################################################################################

#################################################################################
### Logistics and getting started.
#################################################################################

## Clear workspace and clean up memory:
rm(list=ls())
gc(reset=TRUE)

## Load libraries:
library(data.table)
library(dplyr)
library(suncalc)


## Read in data:
load("Data/DiurnalData/alan_dataframes/onset_data_conf_0.75_det_100_grid_10.RData")
load("Data/DiurnalData/alan_dataframes/cessation_data_conf_0.75_det_100_grid_10.RData")

onset <- final
cessation <- final_cess


#################################################################################
### Pair sunlight data - Onset
#################################################################################

## For the onset data, pair light data for "sunrise" for each site/date combo:

#Determine sites to process data for, from df above:
on_sites <- onset |>
  dplyr::select(lat, lon) |>
  dplyr::distinct()


## Add sunlight times to data, by location (coordinates) and date:
on_get <- on_sites |>
  dplyr::cross_join(tibble(date = seq(from = min(onset$date), 
                                      to = max(onset$date), 
                                      by = 1))) |> 
  dplyr::mutate(tz = lutz::tz_lookup_coords(lat, lon)) |>
  distinct()

on_res <- suncalc::getSunlightTimes(
  data = on_get, 
  keep = c("sunrise")) |>
  distinct()

on_res_df <- on_get |>
  dplyr::left_join(on_res) |>
  dplyr::mutate(sunrise = lubridate::with_tz(sunrise, tzone = tz)) #Here, site and date level times

on_light <- onset |> 
  dplyr::left_join(on_res_df)


## Save out a new file:
fwrite(on_light, "Data/DiurnalData/birdcloud_dataframes/onset_light.csv")


#################################################################################
### Pair sunlight data - Cessation
#################################################################################
  
## For the cessation data, pair light data for "sunset" for each site/date combo:

#Determine sites to process data for, from df above:
cess_sites <- cessation |>
  dplyr::select(lat, lon) |>
  dplyr::distinct()


## Add sunlight times to data, by location (coordinates) and date:
cess_get <- cess_sites |>
  dplyr::cross_join(tibble(date = seq(from = min(cessation$date), 
                                      to = max(cessation$date), 
                                      by = 1))) |> 
  dplyr::mutate(tz = lutz::tz_lookup_coords(lat, lon)) |>
  distinct()

cess_res <- suncalc::getSunlightTimes(
  data = cess_get, 
  keep = c("sunset")) |>
  distinct()

cess_res_df <- cess_get |>
  dplyr::left_join(cess_res) |>
  dplyr::mutate(sunset = lubridate::with_tz(sunset, tzone = tz)) #Here, site and date level times

cess_light <- cessation |> 
  dplyr::left_join(cess_res_df)


## Save out a new file:
fwrite(cess_light, "Data/DiurnalData/birdcloud_dataframes/cess_light.csv")






