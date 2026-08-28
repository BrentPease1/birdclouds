# Evaluate stations to keep only stationary stations

library(sf)
library(dplyr)
library(data.table)
library(tidyverse)
library(here)
here::i_am("scripts/L3/302_evaluate_stations.R")

diurn_on_data <- readRDS(
  here("data", "L3", "301_elton_traits", "301a_diurn_on_data.rds")
)
diurn_ev_data <- readRDS(
  here("data", "L3", "301_elton_traits", "301b_diurn_ev_data.rds")
)
noc_data <- readRDS(
  here("data", "L3", "301_elton_traits", "301c_noc_data.rds")
)

## Read in data:
# noc_data <- fread("Data/Final/noc_data.csv")
# diurn_on_data <- fread("Data/Final/diurn_on_data.csv")
# diurn_ev_data <- fread("Data/Final/diurn_ev_data.csv")

## Ensure each station_id has only one coordinate assigned to it.
## To do this, group by station (station_id), take median of lat lons associated
## with that station to get one med_location for each station and then measure
## distance from median to all unique coordinate pairs. If > 5% of the distances
## are > 500m apart, discard the station_id. If station_id only has one unique
## coordinate pair then just keep this one.

#Write function to evaluate multi-coord station ids:
evaluate_stations <- function(id) {
  print(id)

  #subset to only location data:
  data <- d |>
    dplyr::filter(station_id == id) |>
    dplyr::select(latitude, longitude, station_id) |>
    dplyr::distinct()

  check1 <- nrow(data)

  if (check1 == 1) {
    station_coordinate <- data |>
      dplyr::select(station_id, latitude, longitude)

    print("Station has a single point")
  } else {
    print("Several points, function continues")

    #Find the median coord:
    med_coord <- data |>
      dplyr::mutate(med_lat = median(latitude), med_lon = median(longitude)) |>
      dplyr::select(station_id, med_lat, med_lon)

    #Create sf object from all points:
    data_sf <- st_as_sf(data, coords = c("longitude", "latitude"), crs = 4326)

    med_sf <- st_as_sf(med_coord, coords = c("med_lon", "med_lat"), crs = 4326)

    #calculate distances between all unique coords and med coord:
    dist <- sf::st_distance(data_sf, med_sf, by_element = TRUE)

    #Add distances between med to dataframe of coords, identify which
    #are greater than 500:
    dist_data <- data |>
      dplyr::mutate(distance_to_med = as.numeric(dist)) |>
      dplyr::mutate(too_far = ifelse(distance_to_med > 500, 1, 0))

    #Calculate percentage of stations farther than 500m from median:
    dist_percent <- nrow(dist_data[dist_data$too_far == 1, ]) /
      nrow(dist_data) *
      100

    #if dist_percent is > 5%, remove station_id. If < 5%, keep station_id and
    #assign the median coord as its location:

    check2 <- dist_percent > 5

    if (check2) {
      station_coordinate <- c()

      print("Station coordinates too far apart")
    } else {
      station_coordinate <- med_coord |>
        dplyr::distinct() |>
        dplyr::rename(latitude = med_lat, longitude = med_lon)

      print("Station included, med coordinate assigned.")
    }
  }

  return(station_coordinate)
}


## Evaluate all station_ids (by dataset):

#Diurnal onset:

#Assign dataframe and identify the unique station_ids to loop around:
d <- diurn_on_data

stations <- unique(d$station_id)

#Check function works:
check_fun <- evaluate_stations(4275) #it does!

#Loop around all station_ids:
diurn_on_stations <- c()

for (id in stations) {
  all_stations <- evaluate_stations(id)
  diurn_on_stations <- rbind(diurn_on_stations, all_stations)
}


#Diurnal cessation:

#Assign dataframe and identify the unique station_ids to loop around:
d <- diurn_ev_data

stations <- unique(d$station_id)

#Check function works:
check_fun <- evaluate_stations(4275) #it does!

#Loop around all station_ids:
diurn_ev_stations <- c()

for (id in stations) {
  all_stations <- evaluate_stations(id)
  diurn_ev_stations <- rbind(diurn_ev_stations, all_stations)
}


#Nocturnal:

#Assign dataframe and identify the unique station_ids to loop around:
d <- noc_data

stations <- unique(d$station_id)

#Check function works:
check_fun <- evaluate_stations(4275) #it does!

#Loop around all station_ids:
noc_stations <- c()

for (id in stations) {
  all_stations <- evaluate_stations(id)
  noc_stations <- rbind(noc_stations, all_stations)
}

## Join station coordinate data back to full datasets:
diurn_ev <- diurn_ev_data |>
  dplyr::select(-latitude, -longitude) |>
  dplyr::right_join(diurn_ev_stations)

diurn_on <- diurn_on_data |>
  dplyr::select(-latitude, -longitude) |>
  dplyr::right_join(diurn_on_stations)

noc <- noc_data |>
  dplyr::select(-latitude, -longitude) |>
  dplyr::right_join(noc_stations)


saveRDS(
  diurn_on,
  file = here("data", "L3", "302_evaluate_stations", "302a_diurn_on_data.rds")
)
saveRDS(
  diurn_ev,
  file = here("data", "L3", "302_evaluate_stations", "302b_diurn_ev_data.rds")
)
saveRDS(
  noc,
  file = here("data", "L3", "302_evaluate_stations", "302c_noc_data.rds")
)
