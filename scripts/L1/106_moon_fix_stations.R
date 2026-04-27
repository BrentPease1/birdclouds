# In the OPENMETEO station_batches script, the stations were accidentally
# given a new station_id using the `row_number()` function
# This script fixes this mistake for the moon intensity data.

library(tidyverse)
library(here)

here::i_am("scripts/L1/106_moon_fix_stations.R")

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
  here("data", "L1", "completed_batches_buffer"),
  pattern = "*\\.csv"
)

for (b_id in seq_along(batch_list)) {
  cat(sprintf("Processing batch %d: %s\n", b_id, batch_list[b_id]))
  # read in batch
  batch <- read_csv(
    here("data", "L1", "completed_batches_buffer", batch_list[b_id]),
    show_col_types = FALSE
  ) |>
    rename(station = station_id)

  # join brent station IDs
  batch_joined <- batch |>
    left_join(brent_stations, join_by(station == MY_ID)) |>
    select(station_id, everything()) |>
    select(-station)

  # write out new batches
  write_csv(
    batch_joined,
    here("data", "L1", "updated_batches_buffer", batch_list[b_id])
  )
}
