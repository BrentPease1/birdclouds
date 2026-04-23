################################################################################
# title: 102_create_station_dir.R
# toc: true
# format:
#  html:
#    embed-resources: true
# date: 2026-03-06 # last-modified
# date-format: "yyyy-MM-dd"
# abstract: This script takes the unique station lat/long coords and
#           organizes them into subdirectories for batching purposes.
################################################################################

# ------------ SET UP ENVIRONMENT ------------
if (!require("pacman")) {
  install.packages("pacman")
}
pacman::p_load(tidyverse, here)

# Clear envionrment
rm(list = ls())

# Set working directory
here::i_am("scripts/L1/102_create_station_dir.R")


# ------------ LOAD DATA ------------
# Load bird data - only keep unique station locations
bird_stations <- read_csv(here(
  "data",
  "L0",
  "stations_mar2026.csv"
))
# ------------ CREATE BATCHES  ------------

# Create a batch ID for every 60 rows
unique_stations <- bird_stations |>
  mutate(
    station_id = row_number(),
    batch_id = (row_number() - 1) %/% 60
  )

# Create storage directory for station batches
station_batches_path <- here("data", "L1", "station_batches")
dir.create(station_batches_path, showWarnings = FALSE)

batch_results <- list()
MAX_BATCHES <- unique_stations |> pull(batch_id) |> max()


# Get batches with this folder id
current_batches <- unique_stations |>
  pull(batch_id) |>
  unique()

# Loop through each batch to create file
for (b_id in current_batches) {
  file_path <- here(station_batches_path, paste0("batch_", b_id, ".csv"))

  # Get stations with this batch & folder id
  current_batch <- unique_stations |>
    filter(batch_id == b_id)
  write_csv(current_batch, file_path)
}
