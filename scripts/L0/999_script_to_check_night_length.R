library(here)
library(data.table)
library(lubridate)
library(suncalc)
library(lutz)
library(sf)
library(activity)
library(stringr)
setDTthreads(0)


# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
continents <- c("Africa",
                "Asia",
                "Europe",
                "North America",
                "Oceania",
                "South America")

# this stuff helps with reading in the correct file
# need to tact this onto file names below.
months <- data.table(
  name = c(
    "2024_04",
    "2024_05",
    "2024_06",
    "2024_07",
    "2024_08",
    "2024_09",
    "2024_10",
    "2024_11",
    "2024_12",
    "2025_01",
    "2025_02",
    "2025_03",
    "2025_04"
  )
)

# get year column
months[, year := fcase(
  str_detect(name, "^\\d{4}"), as.integer(str_sub(name, 1, 4)),
  str_detect(name, "\\d{4}$"), as.integer(str_extract(name, "\\d{4}$")),
  str_detect(name, "\\d{2}$"), as.integer(paste0("20", str_extract(name, "\\d{2}$")))
)]

# debugging helpers
# c = 'Asia'
# m = 1

if (exists("all_nights")) rm(all_nights)

# start loop to do continent-level calculations
for (c in continents) {
  # current continent
  print(c)
  
  # once we are focused on a given continent, we start processing
  # month by month
  for (m in 1:nrow(months)) {
    # focal month for setting up period variable
    this_month <- months[m, name]
    
    # this_file to be read in
    this_file <- list.files(
      path = paste0(here('data/L0/activity_measures/nocturnal'), "/"),
      pattern = paste0("activity_measures_", gsub(" ", "_", c), "_", this_month, "_conf_0.75_det_20\\.csv$"),
      full.names = T
    )
    
    if (length(this_file) == 0) next
    
    
    # load in Birdweather file
    bw <- fread(this_file)
    
    # parse POSIXct if fread read them as character
    bw[, `:=`(
      night_start = ymd_hms(night_start, tz = "UTC"),
      night_end   = ymd_hms(night_end,   tz = "UTC")
    )]
    
    # calculate night duration in hours
    bw[, night_duration_hrs := as.numeric(difftime(night_end, night_start, units = "hours"))]
    
    # tag source for tracking
    bw[, `:=`(continent = c, month = this_month)]
    
    # collect
    if (!exists("all_nights")) {
      all_nights <- bw[, .(station_id, night_id, night_start, night_end,
                           night_duration_hrs, latitude, longitude,
                           continent, month)]
    } else {
      all_nights <- rbindlist(list(
        all_nights,
        bw[, .(station_id, night_id, night_start, night_end,
               night_duration_hrs, latitude, longitude,
               continent, month)]
      ))
    }
    
  } #months
  
} # continents

# deduplicate since species are stacked in the files - one row per station/night is enough
all_nights <- unique(all_nights, by = c("station_id", "night_id", "continent", "month"))

# quick summary to spot problems
summary(all_nights$night_duration_hrs)

# flag anything over 24 hours
all_nights[night_duration_hrs > 24] #none (was 6 rows of asia during nov 2024, but patched)

# check anything under 5 hours
all_nights[night_duration_hrs < 5, .N, .(continent, month)] #all scandinavia during summer
