# In the OPENMETEO station_batches script, the stations were accidentally
# given a new station_id using the `row_number()` function
# This script fixes this mistake for the openmeteo data.

library(tidyverse)
library(here)

here::i_am("scripts/L1/104_openmeteo_fix_stations.R")

#### for each weather data batch

brent_stations <- read_csv(here(
  "data",
  "L0",
  "stations_mar2026.csv"
)) |>
  mutate(MY_ID = as.double(row_number())) |>
  select(-latitude, -longitude)

# batch list dir (only CSVs)
batch_list <- list.files(
  here("data", "L1", "completed_batches"),
  pattern = "*\\.csv"
)

for (b_id in seq_along(batch_list)) {
  # read in batch
  batch <- read_csv(here("data", "L1", "completed_batches", batch_list[b_id]))

  # join brent station IDs
  batch_joined <- batch |>
    left_join(brent_stations, join_by(station == MY_ID)) |>
    select(station_id, batch_id, everything()) |>
    select(-station)

  # write out new batches
  write_csv(
    batch_joined,
    here("data", "L1", "updated_batches", batch_list[b_id])
  )
}


# check out new batches
batch0 <- read_csv(here("data", "L1", "updated_batches", "batch_0.csv"))
batch1 <- read_csv(here("data", "L1", "updated_batches", "batch_1.csv"))
