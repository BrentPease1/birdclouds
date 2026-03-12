library(tidyverse)
library(data.table)

d <- readr::read_csv("C:/Users/negilbe/OneDrive - Oklahoma A and M System/ALAN Cloud/Asia_mar24.csv")
d <- readr::read_csv("Africa_detections_2024_04.csv")
# unique station name x date combos
stat_dates <- d |> 
  dplyr::mutate(datetime = lubridate::ymd_hms(timestamp,
                                              tz = "UTC")) |> 
  dplyr::mutate(date = lubridate::as_date(datetime)) |> 
  dplyr::select(station_id, date) |> 
  dplyr::distinct()

# dumb quick approach - grabbing first set of lat-lons per station_id
stat_lats <- d |> 
  dplyr::select(lat = latitude, lon = longitude, station_id) |> 
  dplyr::distinct() |> 
  dplyr::group_by(station_id) |> 
  dplyr::slice(1) |> 
  dplyr::ungroup()

# station-specific sequence of dates
station_dates <- stat_dates |> 
  dplyr::left_join(stat_lats) |> 
  dplyr::group_by(station_id) |> 
  dplyr::mutate(first_date = min(date),
                last_date = max(date)) |> 
  dplyr::select(-date) |> 
  dplyr::distinct() |> 
  dplyr::mutate(date = list(seq(first_date, last_date, by = "1 day"))) |> 
  tidyr::unnest(date) |> 
  dplyr::ungroup() |> 
  dplyr::select(station_id, lat, lon, date)

# grab sunset and sunrise time
sun_times <- suncalc::getSunlightTimes(
  data = station_dates, 
  keep = c("sunset", "sunrise"), 
  tz = "UTC") |> 
  tibble::as_tibble()

nights <- sun_times |> 
  dplyr::left_join(station_dates) |> 
  dplyr::group_by(station_id) |> 
  dplyr::mutate( night_start = sunset,    
                 night_end = lead(sunrise), 
                 night_id = dplyr::row_number()) |> 
  dplyr::filter(!is.na(night_end)) |> 
  dplyr::select(station_id, night_id, night_start, night_end) |> 
  dplyr::ungroup()

# example...just grabbing owls...
owls <- d |> 
  dplyr::mutate(datetime = lubridate::ymd_hms(timestamp,
                                              tz = "UTC")) |> 
  dplyr::rename(lat = latitude, lon = longitude)  |> 
  dplyr::left_join(nights, by = "station_id") |> 
  dplyr::filter(datetime >= night_start & datetime < night_end) |> 
  dplyr::filter(grepl("owl", ignore.case = TRUE, common_name)) |> 
  dplyr::select(species = common_name, station_id, datetime)
  

# data.table go brrrrrrrrrr
data.table::setDT( nights )
data.table::setDT( owls )

# join the owl and night table, so we have detections & corresponding night id
owl_night <- nights[
  owls, 
  on = .( station_id, 
          night_start <= datetime, 
          night_end > datetime), 
  nomatch = 0
]

# unique species x station combos - don't want to blow things up with 
# all possible combos
sp_stat <- unique(
  owl_night[, .(species, station_id)]
)

# station / night combo
night_station <- nights[, .(station_id, night_id)]

# template
template <- merge(
  sp_stat, 
  night_station,
  by = "station_id", 
  allow.cartesian = TRUE
)

# detections
dh <- owl_night[
  ,
  .(det = 1),
  by = .(species, station_id, night_id)
]

det_hist <- merge(
  template, 
  dh,
  by = c("species", "station_id", "night_id"),
  all.x = TRUE)

det_hist[is.na(det), det := 0]
