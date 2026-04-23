# This script repurposes a script from the ALAN paper, specifically the following
# https://github.com/BrentPease1/alan/blob/main/Scripts/102_data-prep_extract_viirs.R
# to extract monthly VIIRS data for each station across the study period.

# This script is designed to run on a D drive (or equivalent harddrive)
# containing VIIRS data, where the data & scripts are organized as follows:
# D:/
#  data/
#    VIIRS_unzipped/
#      2023/../
#      2024/
#        01/
#           "SVDNB_npp_20230301-20230331_00N060E_vcmslcfg_v10_c202304101100.avg_rade9h.tif"
#           "SVDNB_npp_20230301-20230331_00N060E_vcmslcfg_v10_c202304101100.cf_cvg.tif"
#           "SVDNB_npp_20230301-20230331_00N060E_vcmslcfg_v10_c202304101100.cvg.tif"
#           "SVDNB_npp_20230301-20230331_00N060W_vcmslcfg_v10_c202304101100.avg_rade9h.tif"
#           "SVDNB_npp_20230301-20230331_00N060W_vcmslcfg_v10_c202304101100.cf_cvg.tif"
#           "SVDNB_npp_20230301-20230331_00N060W_vcmslcfg_v10_c202304101100.cvg.tif"
#           "SVDNB_npp_20230301-20230331_00N180W_vcmslcfg_v10_c202304101100.avg_rade9h.tif"
#           "SVDNB_npp_20230301-20230331_00N180W_vcmslcfg_v10_c202304101100.cf_cvg.tif"
#           "SVDNB_npp_20230301-20230331_00N180W_vcmslcfg_v10_c202304101100.cvg.tif"
#           "SVDNB_npp_20230301-20230331_75N060E_vcmslcfg_v10_c202304101100.avg_rade9h.tif"
#           "SVDNB_npp_20230301-20230331_75N060E_vcmslcfg_v10_c202304101100.cf_cvg.tif"
#           "SVDNB_npp_20230301-20230331_75N060E_vcmslcfg_v10_c202304101100.cvg.tif"
#           "SVDNB_npp_20230301-20230331_75N060W_vcmslcfg_v10_c202304101100.avg_rade9h.tif"
#           "SVDNB_npp_20230301-20230331_75N060W_vcmslcfg_v10_c202304101100.cf_cvg.tif"
#           "SVDNB_npp_20230301-20230331_75N060W_vcmslcfg_v10_c202304101100.cvg.tif"
#           "SVDNB_npp_20230301-20230331_75N180W_vcmslcfg_v10_c202304101100.avg_rade9h.tif"
#           "SVDNB_npp_20230301-20230331_75N180W_vcmslcfg_v10_c202304101100.cf_cvg.tif"
#           "SVDNB_npp_20230301-20230331_75N180W_vcmslcfg_v10_c202304101100.cvg.tif"
#        02/../
#        ../../
#        12/../
#      2025/../
#  scripts/
#    101_extract_VIIRS.R

# The output script should be moved to the following directory:
# birdclouds/data/L1/101_stations_with_VIIRS_2026_03_06.csv

# ------------ SET UP ENVIRONMENT ------------
# Load in packages
if (!require("pacman")) {
  install.packages("pacman")
}
pacman::p_load(here, tidyverse, data.table, lubridate, sf, terra, rworldmap)

# Clear envionrment
rm(list = ls())

setDTthreads(0)
overwrite = T


here::i_am("scripts/101_extract_VIIRS.R")

# ------------ READ DATA ------------

# station data
raw_data <- read_csv(here(
  "data",
  "stations_mar2026.csv"
))

date_col <- raw_data |>
  names() |>
  str_detect("date")

# if raw data contains column 'date'
if (any(date_col)) {
  # Get month and year from date column
  # used for handling data already with vocalizations/detections
  va <- raw_data |>
    mutate(
      date = ymd(date),
      month = str_pad(month(date), width = 2, pad = "0"),
      year = as.character(year(date))
    ) |>
    arrange(year, month) |>
    data.table::as.data.table()
} else {
  # Create month 0-12 and years 2023-2025 for each station
  # used for handling data with only station info
  va <- raw_data |>
    rename(lon = longitude, lat = latitude) |>
    crossing(
      year = as.character(2023:2025),
      month = str_pad(1:12, width = 2, pad = "0")
    ) |>
    arrange(year, month) |>
    data.table::as.data.table()
  # note some station names have the same lat/lon as other stations
  # so there are fewer unique lat/lon combos than unique stations
  unique(raw_data$station) |> length() # number of stations
  unique(va[, .(lat, lon)]) |> nrow() # number of lat/lon combos
}


# get unique locations for extracting VIIRS
va[, lat_lon := .GRP, .(lat, lon)]
va_locs <- va[!duplicated(lat_lon), .(lat_lon, lat, lon)]
va_locs <- st_as_sf(va_locs, coords = c('lon', 'lat'), crs = 4326)


# ------------ CALCULATE RADIANCE FROM VIIRS ------------

# FX: Get list of VIIRS files for given year and month
GetVIIRSFileList <- function(year, month) {
  file_path <- here(base_file, year, month)
  if (file.exists(file_path)) {
    list <- list.files(
      file_path,
      pattern = "\\.avg_rade9h\\.tif$",
      full.names = TRUE,
      recursive = TRUE
    )
  } else {
    return() # null if dir doesn't exist
  }
}

# Initilization for looping through years and months of VIIRS data
base_file <- "D:/data/VIIRS_unzipped"

years <- unique(va$year)
months <- unique(va$month)
months <- c("01", "02", setdiff(months, c("01", "02")))

va_holder <- list()
va_counter <- 0


# Loop through VIIRS data for each year/month and extract radiance for each lat/lon combo
for (y in seq_along(years)) {
  for (m in seq_along(months)) {
    # read in viirs files and stack with `terra`
    nt_files <- GetVIIRSFileList(years[[y]], months[[m]])

    # Skip processing files if dir was empty
    if (is.null(nt_files)) {
      cat(
        sprintf(
          "no files found for year %s month %s\n",
          years[[y]],
          months[[m]]
        )
      )
      next
    } else {
      cat(sprintf("processing year %s month %s\n", years[[y]], months[[m]]))
    }

    # Read each raster individually because of different extents
    nt_rast <- lapply(nt_files, terra::rast)

    # loop through each file and try to extract values
    # will return NAs for non-overlapping points
    nt_holder <- list()
    for (i in 1:length(nt_rast)) {
      this_rast <- nt_rast[[i]]
      nt_holder[[i]] <- extract(this_rast, vect(va_locs))
      names(nt_holder[[i]]) <- c('ID', paste0('avg_rad_', i))
    }

    # bring together
    combined_df <- Reduce(
      function(x, y) merge(x, y, by = "ID", all = TRUE),
      nt_holder
    )

    # Just get single value across all columns
    combined_df$avg_rad <- apply(
      combined_df[, grep("avg_rad", names(combined_df))],
      1,
      function(x) {
        # Return the first non-NA value or NA if all are NA
        x[which(!is.na(x))[1]]
      }
    )
    # keep the two columns
    nt_estimates <- combined_df[, c("ID", "avg_rad")]
    setDT(nt_estimates)
    setkey(nt_estimates, "ID")

    # Merge avg_rad to temp copy with only the year/month being processed
    va_subset <- va[year == years[[y]] & month == months[[m]]]

    # Join the rad values to this subset
    va_subset <- merge(
      va_subset,
      nt_estimates,
      by.x = "lat_lon",
      by.y = "ID",
      all.x = TRUE
    )

    # Save this processed subset to holder
    va_counter <- va_counter + 1
    va_holder[[va_counter]] <- va_subset
  }
}

# Combine all processed months into one table
out <- rbindlist(va_holder)

# categorize nighttime light
out[,
  rad_cat := fcase(
    avg_rad < quantile(avg_rad, probs = 0.334, na.rm = T)                                                          , "low"  ,
    avg_rad >= quantile(avg_rad, probs = 0.334, na.rm = T) & avg_rad < quantile(avg_rad, probs = 0.667, na.rm = T) , "med"  ,
    avg_rad >= quantile(avg_rad, probs = 0.667, na.rm = T)                                                         , "high"
  )
]

# update lat_lon group
out[, lat_lon := .GRP, .(lat, lon)]


fwrite(out, here("data", "101_stations_with_VIIRS_2026_03_06.csv"))


##### For data with data cols, notice discrepancy between `out` and `raw_data`
if (any(date_col)) {
  nrow(raw_data) - nrow(out)

  # Stations may occur outside of VIIRS data range (Mar 2023- Jun 2025)
  # VIIRS & weather data was not pulled past Jun 30,2025
  # 303 stations occur on July 1, 2025
  # Thus, this data is dropped
  raw_data |>
    mutate(
      date = ymd(date),
      month = str_pad(month(date), width = 2, pad = "0"),
      year = as.character(year(date))
    ) |>
    count(year, month) |>
    anti_join(
      out |> distinct(year, month),
      by = c("year", "month")
    )
}

# clear out memory
rm(list = ls()[!ls() %in% c("out")])
gc()
