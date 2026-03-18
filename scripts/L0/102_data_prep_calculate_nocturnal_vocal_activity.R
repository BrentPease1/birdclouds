library(here)
library(data.table)
library(lubridate)
library(suncalc)
library(lutz)
library(sf)
library(activity)
library(stringr)
setDTthreads(0)

# functions
remove_unwanted_spp <- function(dt) {
  not_interested <- c(
    "Engine", "Siren", "Coyote", "Dog", "Eastern Gray Squirrel",
    "Red Squirrel", "Power tools", "Fireworks", "Gray Wolf", "Gun",
    "Honey Bee", "Spring Peeper"
  )
  
  like_patterns <- c(
    "Treefrog", "Bullfrog", "Cricket", "Toad", "Trig", "Katydid",
    "Chipmunk", "Conehead", "Gryllus assimilis", "Human", "Monkey"
  )
  
  dt[
    !(common_name %in% not_interested) &
      !(str_detect(common_name, "[Ff]rog(?!mouth)")) &
      !Reduce(`|`, lapply(like_patterns, function(p) common_name %like% p))
  ]
}



fill_missing_night_end <- function(dt) {
  missing_idx <- which(is.na(dt$night_end))
  
  if (length(missing_idx) == 0) return(dt)
  
  for (idx in missing_idx) {
    next_day <- as.Date(dt$night_start[idx]) + 1
    lat      <- dt$latitude[[idx]]
    lon      <- dt$longitude[[idx]]
    
    sunrise_times <- getSunlightTimes(
      date = next_day,
      lat  = lat,
      lon  = lon,
      tz   = "UTC"
    )
    
    dt$night_end[idx] <- sunrise_times$sunrise
  }
  
  dt
}



# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

confidence_cutoff <- c(0.75)
detection_filter <- c(20)
continents <- c("Africa",
                "Asia",
                "Europe",
                "North America",
                "Oceania",
                "South America")

# file base name
base <- "E:/bird_acitivity/Results/bird_detections_by_continent_and_month"

# pull in continent shapefile for filtering lat / lon below
continent_shapes <- spData::world

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
      path = base,
      pattern = paste0(gsub(" ", "_", c), ".*", this_month, "\\.csv$"),
      full.names = T
    )
    
    # load in Birdweather file
    bw <- fread(this_file)
    
    # keep pucs and pis only
    bw <- bw[station_type %in% c('puc', 'birdnetpi'), ]
    
    # column clarity
    setnames(bw, old = c("id"), new = c('detection_id'))
    
    # extract date and a few helper columns 
    bw[, `:=`(datetime = lubridate::ymd_hms(timestamp,tz = "UTC"),
              date = lubridate::as_date(timestamp),
              continent = c,
              year = months[m, year])]
    # throw out failures
    bw <- bw[!is.na(datetime)] 
    # a couple more helpers    
    bw[, `:=`(week = week(datetime),
              month = month(date))]
    
    # filter birdnet confidence score (variable defined in preamble)
    bw <- bw[confidence >= confidence_cutoff, ]
    
    # spatially filter down to continent
    # traveling pucs, birdweather app etc cause issues so this throws out data beyond the focal continent
    # For example, a birdweather app was being used in China and British Columbia during the same month
    # because the person did a bird id on a hike in the canadian rockies
    
    # make a row-index placeholder
    bw$index <- 1:nrow(bw)
    # copy to not mess up original
    tmp <- bw
    # make spatial object
    tmp <- st_as_sf(tmp,
                    coords = c("longitude", "latitude"),
                    crs = 4326)
    # which points fall within focal continent
    # returns an NA when outside, a 1 when inside
    t <- sapply(st_intersects(tmp, continent_shapes |>
                                dplyr::filter(continent == c)), function(z)
                                  if (length(z) == 0)
                                    NA_integer_
                else
                  z[1])
    # filters down the tmp to just 1s (within-continent_)
    tmp <- tmp[!is.na(t), ]
    # throw out vector
    rm(t)
    # sub down primary bw using the leftover index values in tmp
    bw <- bw[bw$index %in% tmp$index, ]
    # clean
    rm(tmp)
    gc()
    
    # remove spp we don't care about, function at top
    bw <- remove_unwanted_spp(bw)
    
    # count the detections per spp per station-date
    total_spp <- bw[, .N, by = .(common_name, species_id, station_id)]
    
    total_spp <- total_spp[N > detection_filter, ] #min observations per species per station_date
    focal_spp <- total_spp[, unique(common_name)]
    focal_spp <- sort(focal_spp)
    
    
    
    # ok, a bit more work to do 
    # consistent stations (at least a week during the month)
    these_stations <- bw[, uniqueN(date), station_id][V1 >= 7] # which stations have run for at least a week
    bw <- bw[station_id %in% these_stations$station_id]
    
    # figure out how long each station ran
    bw[, `:=`(first_date = min(date), 
              last_date = max(date)), by = station_id]
    
    # get 1 row for each station
    unique_stations <- bw[, .(latitude = latitude[1],
                              longitude = longitude[1],
                              first_date = first_date[1],
                              last_date =last_date[1]),
                          by = station_id]
    
    # expand for a row each day, should result in stations x number of days operated/station
    unique_stations <- unique_stations[, .(date = seq(first_date, last_date, by = "1 day"),
                                           lon = longitude,
                                           lat = latitude), 
                                       by = station_id]
    
    # grab sunset and sunrise time
    sun_times <- suncalc::getSunlightTimes(
      data = unique_stations[, .(date, lat, lon)], 
      keep = c("sunset", "sunrise"), 
      tz = "UTC")
    sun_times <- setDT(sun_times)
    
    # join suncalc, its clean I promise :)
    unique_stations <- cbind(unique_stations, sun_times[, .(sunrise, sunset)])
    
    ################# OLD LOGIC FOR NIGHT START/END ###################
    # use suncalc data to calculate night start and end
    #unique_stations[, `:=`(night_start = sunset,
    #                       night_end = shift(sunrise, n = 1, type = "lead"),
    #                       night_id = seq_len(.N)), by = station_id]
    ########################################################################

    ################## START OF NEW NIGHT START/END LOGIC ##################
    # Arrange the stations and dates!!!
    setorder(unique_stations, station_id, date)
    
    # Calculate night start and end - [more complicated version!]
    unique_stations[,
      `:=`(
        night_start = sunset,
        night_end = dplyr::if_else(
          shift(date, type = "lead") == date + 1, # Check if NEXT row is exactly +1 day from current row
          shift(sunrise, type = "lead"), # If it is, grab the sunrise
          as.POSIXct(NA, tz = "UTC") # If not, there's a gap, so give it an NA; forced to data class as a safety
        ),
        # Force night_id to be the day of the month, instead of using row sequencing logic
        night_id = lubridate::mday(date)
      ),
      by = station_id
    ]
    
    # Thus, for a given date:
    # night_id = the day of the date (e.g., Jan 1)
    # night_start = sunset of current date (e.g., sunset on Jan 1)
    # night_end = sunrise of following date (e.g., sunrise on Jan 2)
    
    # --- Optional: Clean up weird nights ---
    # These nights could be filtered out now if you have time to check them
    # Alternatively, leave these in for Karina to explore & remove in downstream analyses
    # > Remove issue where sunset is after sunrise (probably caused by daylight savings time)
    # > Remove gap issue where night_end is NA
    unique_stations <- unique_stations[!is.na(night_end) & night_start < night_end]
    ################## END OF NEW NIGHT START/END LOGIC ##################
    
    # keep just a few columns
    unique_stations <- unique_stations[, .(station_id, night_id, night_start, night_end)]
    #stashing a copy for below to merge in night_start and _end for karina
    keep_nights <- unique_stations
    
    # species holders
    species_holder <- list()
    species_counter = 0
   
    # debugging helper
    # f = focal_spp[1]
    
    for (f in focal_spp) {
      species_counter = species_counter + 1
      single_spp_dets <- bw[common_name == f, ]
      
      # doing a bunch of neil stuff
      setnames(single_spp_dets, old = c('latitude', 'longitude'),new = c('lat', 'lon'))
      
      # join night start and end with bw data
      single_spp_dets <- single_spp_dets[unique_stations, on = .(station_id), 
                                         allow.cartesian = TRUE]
      
      # filter to night time
      single_spp_dets <- single_spp_dets[datetime >= night_start & datetime < night_end]
      
      # unique species x station combos - don't want to blow things up with 
      # all possible combos
      sp_stat <- unique(
        single_spp_dets[, .(common_name, station_id)]
      )
      
      # keep just a few columns
      #     single_spp_dets <- single_spp_dets[,.(common_name, station_id, datetime)]
      
      # station / night combo
      night_station <- unique_stations[, .(station_id, night_id)]
      
      # template
      template <- night_station[sp_stat, on = .(station_id), allow.cartesian = T]
      
      # detections
      dh <- single_spp_dets[, .(det = 1),by = .(common_name, station_id, night_id)]
      
      # output
      det_hist <- merge(
        template, 
        dh,
        by = c("common_name", "station_id", "night_id"),
        all.x = TRUE)
      
      det_hist[is.na(det), det := 0]
      
      setkey(det_hist, station_id)
      
      # one more grab to export with everything
      out <- keep_nights[det_hist, on = .(station_id, night_id), allow.cartesian = F]
      # pull in lat/lon
      out <- out[bw[station_id %in% out$station_id,.(latitude = latitude[1], longitude=longitude[1]), station_id], on = .(station_id)]
      out <- fill_missing_night_end(out)
      
      # drop station_date grouping variable
      species_holder[[species_counter]] <- out
      
    } #species
    species_holder <- rbindlist(species_holder)
    # make sure directory exists
    ifelse(!dir.exists(file.path(
      here('data/L0/activity_measures/nocturnal')
    )), dir.create(file.path(
      here('data/L0/activity_measures/nocturnal')
    )), FALSE)
    # write file to directory
    fwrite(
      species_holder,
      file = paste0(
        here('data/L0/activity_measures/nocturnal'),
        "/activity_measures_",
        c,
        "_",
        this_month,
        "_conf_" ,
        confidence_cutoff,
        "_det_",
        detection_filter,
        ".csv"
      )
    )
    
    
    cat(
      '\n\n',
      c,
      this_month,
      "confidence_cutoff",
      confidence_cutoff,
      "detection_filter",
      detection_filter,
      'completed',
      'at',
      as.character(Sys.time()),
      "\n\n"
    )
    
    
  } # months
  
} #continents
