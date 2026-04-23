################################################################################
# title: 103_openmeteo_fetch_data.R
# toc: true
# format:
#  html:
#    embed-resources: true
# date: 2026-04-22 # last-modified
# date-format: "yyyy-MM-dd"
# abstract: This script retrieves weather data from the open-meteo API for each
#           BirdWeather station, based on some batching and subdirectory logic
#           to distribute API calls.
#           Note: ADD THE API KEY IN THE fetch_weather() FUNCTION BELOW!
################################################################################

# ------------ SET UP ENVIRONMENT ------------
# Load in packages
if (!require("pacman")) {
  install.packages("pacman")
}
pacman::p_load(httr, jsonlite, tidyverse, here)

# Clear envionrment
rm(list = ls())

# Set working directory
here::i_am("scripts/L1/103_openmeteo_fetch_data.R")


# ------------ API FUNCTION ------------

# Function to fetch data from the Open-Meteo Historical Weather API
# NOT the Historical Forecast API because the latter is the forecast, and the
# former is the corrected version of the forecast with data assimilation from
# what actually occurred

fetch_weather <- function(station, lat, lon, start_date, end_date) {
  # <- "https://archive-api.open-meteo.com/v1/archive"
  url <- "https://customer-archive-api.open-meteo.com/v1/archive"
  params <- list(
    latitude = lat,
    longitude = lon,
    start_date = start_date,
    end_date = end_date,
    models = "ecmwf_ifs", # only use this model to prevent discrepancies in different mdoel algorithms and resolutions
    hourly = "cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,precipitation,rain,snowfall",
    apikey = "" # ADD API KEY HERE!
  )

  response <- GET(url, query = params, timeout(1200)) # Give API up to 20mins to find data

  # Check for HTTP errors
  if (http_error(response)) {
    stop(sprintf(
      "HTTP Error: %s",
      http_status(response)$message
    ))
  }

  # Parse JSON response
  content <- content(response, "text", encoding = "UTF-8")
  data <- fromJSON(content, flatten = TRUE)

  # Convert to a data frame
  df <- as.data.frame(data$hourly)

  # Get units
  units_df <- as.data.frame(data$hourly_units)

  # add units to df column names
  for (col in names(df)) {
    unit <- units_df[[col]]
    new_col_name <- paste0(col, "_", unit)
    names(df)[names(df) == col] <- new_col_name
  }

  # Get local weather station info
  weather_info <- list(
    data$latitude,
    data$longitude,
    data$utc_offset_seconds,
    data$timezone,
    data$timezone_abbreviation,
    data$elevation
  )
  names(weather_info) <- c(
    "weather_stat_latitude",
    "weather_stat_longitude",
    "weather_stat_utc_offset_seconds",
    "weather_stat_timezone",
    "weather_stat_timezone_abbr",
    "weather_stat_elevation"
  )

  for (info in names(weather_info)) {
    df[[info]] <- weather_info[[info]]
  }

  df <- df |>
    mutate(station = station) |>
    select(station, everything())

  df
}

# ------------ TIME FUNCTION ------------
# FX: Reformats system time to a string
GetTime <- function() {
  format(Sys.time(), "%Y-%m-%d %H:%M:%S")
}

# ------------ SLEEP FUNCTION ------------
# FX: Puts script to sleep and indicate in console
PutToSleep <- function(sec) {
  cat(sprintf(
    "[%s] ... system is at rest ... next API call will begin in %d seconds ...\n",
    GetTime(),
    sec
  ))
  #Sys.sleep(sec)
}

#SLEEP_TIME <- 520
# If using the free API plan:
# Each station call is equivalent to ~60 calls from the API (conservative estimate).
# API daily limit is 10k, so we can only run about 160 stations a day
# [86400 sec / (10000 call limit / 60 calls per station)] ~ 520 sec between calls

# You can run 32 batches a day because each batch contains 5 stations
#   and each station is roughly equal to 60 API calls
# (conservative estimate; actual amount is around 48-50 API calls).
# Thus, 32*5*60 = 9600, which just short of the 10k API limit

# ------------ CONSOLE INFO FUNCTION ------------
WriteConsole <- function(
  # Default values assigned to catch errors
  batch = 999,
  attempt = 999,
  max_retries = 999,
  station_num = 999,
  max_station = 999,
  station_name = "DEFAULT",
  custom_string = "DEFAULT"
) {
  cat(sprintf(
    "[%s] > Batch %d; Attempt %d of %d; Station %d of %d: `%s` %s\n",
    GetTime(),
    batch,
    attempt,
    max_retries,
    station_num,
    max_station,
    station_name,
    custom_string
  ))
}


# ------------ GET WEATHER DATA ------------

# Specify a folder containing all the batches to run
folder_name <- "station_batches"


# --- Add console output to log ---
# Create log directory and file
logs_path <- here("data", "L1", "logs")
if (!dir.exists(logs_path)) {
  dir.create(logs_path)
}
log_file <- here(logs_path, paste0("log_", folder_name, ".txt"))

if (file.exists(log_file)) {
  cat(sprintf(
    "\n%s\n[%s] SCRIPT STARTING\n%s\n",
    strrep("*", 60),
    GetTime(),
    strrep("*", 60)
  ))
}

# Sink console output to a log file to examine potential issues
sink(log_file, split = TRUE, append = TRUE)


# --- Start getting weather data ---

# Define path of folder to run
folder_path <- here("data", "L1", folder_name)

batches <- dir(folder_path)

# Loop thru your folder of batches
cat(sprintf("\n[%s] **** Starting to process %s ****", GetTime(), folder_name))
for (batch in seq_along(batches)) {
  batch_name <- batches[batch]
  cat(sprintf(
    "\n[%s] Reading batch %d of %d: %s\n",
    GetTime(),
    batch,
    max(seq_along(batches)),
    batch_name
  ))

  # Read in current btch
  current_batch <- read_csv(
    here(folder_path, batch_name),
    show_col_types = FALSE
  )

  # Path for finished batch doesn't need to be organized into folders
  comp_batch_folder_path <- here("data", "L1", "completed_batches")
  if (!dir.exists(comp_batch_folder_path)) {
    dir.create(comp_batch_folder_path)
  }
  comp_batch_path <- here("data", "L1", "completed_batches", batch_name)

  batch_results <- list()

  if (file.exists(comp_batch_path)) {
    cat(sprintf(
      "[%s] >>> Skipping batch %d, `%s` because batch has already been processed.",
      GetTime(),
      batch,
      batch_name
    ))
    next
  }

  cat(sprintf(
    "[%s] *** Trying to process stations in `%s` ***\n",
    GetTime(),
    batch_name
  ))

  for (x in seq_len(nrow(current_batch))) {
    row <- current_batch |> slice(x)

    tryCatch(
      {
        ### Retry logic if errors come up, particularly to catch timeout errors
        max_retries <- 3
        attempt <- 1
        result <- NULL

        while (attempt <= 3 && is.null(result)) {
          WriteConsole(
            batch,
            attempt,
            max_retries,
            x,
            nrow(current_batch),
            row$station_id,
            "[FETCHING]"
          )

          result <- tryCatch(
            {
              fetch_weather(
                row$station_id,
                row$latitude,
                row$longitude,
                "2023-03-01",
                "2025-06-30"
              )
            },
            error = function(e) {
              if (attempt < max_retries) {
                WriteConsole(
                  batch,
                  attempt,
                  max_retries,
                  x,
                  nrow(current_batch),
                  row$station_id,
                  "[FAILED]"
                )
                cat(sprintf(">>>>> ERROR: `%s`\n", e$message))

                #PutToSleep(SLEEP_TIME)
                return(NULL)
              } else {
                stop(e) # Throw error to outer trycatch after 3rd attempt fails
              }
            }
          )
          attempt <- attempt + 1
        }

        batch_results[[x]] <- result
        WriteConsole(
          batch,
          (attempt - 1),
          max_retries,
          x,
          nrow(current_batch),
          row$station_id,
          "[COMPLETED]"
        )

        #PutToSleep(SLEEP_TIME)
      },
      error = function(e) {
        cat(sprintf(
          "%s\n[%s] > Batch %d; ERROR WITH STATION `%s`:\n>>>>> %s\n%s\n",
          strrep("*", 30),
          GetTime(),
          batch,
          row$station_id,
          e$message,
          strrep("*", 30)
        ))
        if (grepl("429|504", tolower(e$message))) {
          # Close sink before stopping
          sink()

          stop(
            paste0(
              strrep("!", 30),
              "\n> API LIMIT REACHED! Stopping script to preserve progress\n",
              strrep("!", 30),
              "\n"
            )
          )
        }
      }
    )
  }
  if (length(batch_results) > 0) {
    # Combine all stations in a batch and add station, batch, and folder IDs
    batch_df <- bind_rows(batch_results) |> # Combine stations
      left_join(current_batch, by = c("station" = "station_id")) # Add IDs

    # Save batch to file
    write_csv(batch_df, comp_batch_path)
    # also save as Rdata just in case
    save(batch_df, file = sub("\\.csv$", ".Rdata", comp_batch_path))

    cat(sprintf(
      "[%s] *** Successfully saved batch %d of %d: `%s` ***\n",
      GetTime(),
      batch,
      max(seq_along(batches)),
      batch_name
    ))
  }
}

# --- End logging ---
sink()
