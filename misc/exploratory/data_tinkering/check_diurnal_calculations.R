library(tidyverse)
library(sf)
library(mapview)
library(here)

repo_path <- "misc/exploratory/data_tinkering"

here::i_am(paste0(repo_path, "/check_diurnal_calculations.R"))

d <- read_csv(here(repo_path, "questionable.csv"))

t <- st_as_sf(d, coords = c('longitude', 'latitude'), crs = 4326)
mapview(t)

# 75 / 83 cessation problems are negative - i.e. happening before sunset
# largest value is 11.6 hr before sunset
d |>
  dplyr::filter(category == "ev_ces") |>
  dplyr::mutate(neg = ifelse(value < 0, 1, 0)) |>
  pull(neg) |>
  sum()

# 85/91 onset problems are positive, i.e. happening after sunrise
d |>
  dplyr::filter(category == "first_onset") |>
  dplyr::filter(value > 0)


# weird behavior -
# quite a few rows (75%) have identical first onset and median dawn values
d |>
  filter(!category == "ev_ces") |>
  # group_by(station_id, date, common_name) |>
  pivot_wider(names_from = category, values_from = value) |>
  mutate(flag = ifelse(first_onset == median_dawn, 1, 0)) |>
  dplyr::filter(!is.na(flag)) |>
  # mutate(flag = ifelse(is.na(flag), 0, flag)) |>
  dplyr::summarise(
    tot = sum(flag),
    prop = sum(flag, na.rm = TRUE) / sum(!is.na(flag))
  )

# most stations just have 1 or 2...
# 1 has 165, another has 74
d |>
  dplyr::count(station_id)
