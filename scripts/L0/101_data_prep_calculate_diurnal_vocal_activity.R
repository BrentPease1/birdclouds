library(here)
library(data.table)
library(lubridate)
library(suncalc)
library(lutz)
library(sf)
library(activity)
library(stringr)
setDTthreads(0)

# overwrite current files?
overwrite <- T


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

## Create empty lists to fill with data as it's read in:
## first one holds months by continent, second combines continents
results_list <- list(list())

results_list_continent <- list(list())

for (c in continents) {
  print(c)
  
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
  
  for (m in 1:nrow(months)) {
    # focal month for setting up period variable
    this_month <- months[m, name]
    # this_file to be read in
    this_file <- list.files(
      path = base,
      pattern = paste0(gsub(" ", "_", c), ".*", this_month, "\\.csv$"),
      full.names = T
    )
    
    # load in Birdweather
    bw <- fread(this_file)
    
    # keep pucs and pis only
    bw <- bw[station_type %in% c('puc', 'birdnetpi'), ]
    
    # column clarity
    setnames(bw, old = c("id"), new = c('detection_id'))
    
    bw[, date := lubridate::as_date(timestamp)]
    bw[, `:=`(continent = c,
              month = month(date),
              year = months[m, year])]
    
    # filter birdnet confidence score
    bw <- bw[confidence >= confidence_cutoff, ]
    
    # filter down to continent
    # traveling pucs, etc cause issues
    
    bw$index <- 1:nrow(bw)
    tmp <- bw
    tmp <- st_as_sf(tmp,
                    coords = c("longitude", "latitude"),
                    crs = 4326)
    t <- sapply(st_intersects(tmp, continent_shapes |>
                                dplyr::filter(continent == c)), function(z)
                                  if (length(z) == 0)
                                    NA_integer_
                else
                  z[1])
    tmp <- tmp[!is.na(t), ]
    rm(t)
    bw <- bw[bw$index %in% tmp$index, ]
    rm(tmp)
    
    
    # initial prep of bw timestamps
    bw[, date_time := ymd_hms(timestamp, tz = 'UTC')]
    bw <- bw[!is.na(date_time)] # failed to parse, didn't have timestamp, just date
    bw[, date := date(date_time)]
    bw[, week := week(date_time)]
    
    # get grouping variables
    bw[, station_date := .GRP, .(station_id, date)]
    setkey(bw, station_date)
    
    # remove noise, mammals, insects, and amphibians
    not_interested <- c(
      "Engine",
      "Siren",
      "Coyote",
      "Dog",
      "Eastern Gray Squirrel",
      "Red Squirrel",
      "Power tools",
      "Fireworks",
      "Gray Wolf",
      "Gun",
      "Honey Bee",
      "Spring Peeper"
    )
    total_spp <- bw[!(common_name %in% not_interested), ]
    # this should keep frogmouths but drop anuras
    total_spp <- total_spp[!(
      str_detect(common_name, "frog(?!mouth)") |
        str_detect(common_name, "Frog(?!mouth)")
    ), ]
    total_spp <- total_spp[!(common_name %like% "Treefrog"), ]
    total_spp <- total_spp[!(common_name %like% "Bullfrog"), ]
    total_spp <- total_spp[!(common_name %like% "Cricket"), ]
    total_spp <- total_spp[!(common_name %like% "Toad"), ]
    total_spp <- total_spp[!(common_name %like% "Trig"), ]
    total_spp <- total_spp[!(common_name %like% "Katydid"), ]
    total_spp <- total_spp[!(common_name %like% "Chipmunk"), ]
    total_spp <- total_spp[!(common_name %like% "Conehead"), ]
    total_spp <- total_spp[!(common_name %like% "Gryllus assimilis"), ]
    total_spp <- total_spp[!(common_name %like% "Human"), ]
    total_spp <- total_spp[!(common_name %like% "Monkey"), ]
    # count the detections per spp per station-date
    total_spp <- total_spp[, .N, by = .(common_name, species_id, station_date)]
    
    
    # OK, these next lines first calculate
    # how many detections a given species has
    # for each station-date (e.g., raleigh, nc on June 3, 2023)
    # I think we need a minimum number of
    # detections for a species to ensure that
    # the samples on that date are representative
    # of the species.
    # concern that 100 is over restrictive
    # unclear what minimum number should be though
    # 25? 10?

    for (dets in detection_filter) {
      # do I want to overwrite existing output files?
      # TRUE can be used if new analyses or changes needed
      # FALSE to rerun script without overwriting
      if (overwrite == TRUE) {
        cat("")
      } else{
        # check if file exists
        if (file.exists(
          paste0(
            here('data/L0/activity_measures'),
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
        )) {
          cat('\n\n', c, this_month, "completed\n\n")
          
          next
        }
      }
      
      
      
      total_spp <- total_spp[N > detection_filter, ] #min observations per species per station_date
      focal_spp <- total_spp[, unique(common_name)]
      focal_spp <- sort(focal_spp)
      
      species_holder <- list()
      species_counter = 0
      for (f in focal_spp) {
        species_counter = species_counter + 1
        single_spp_dets <- bw[common_name == f, ]
        
        # now start working on timezone and clocks
        # Generate the sunlight times
        time_frame <- getSunlightTimes(
          data = single_spp_dets[, .(date = date,
                                     lat = latitude,
                                     lon = longitude)],
          keep = c(
            "dusk",
            "night",
            "dawn",
            "nightEnd",
            "sunrise",
            "nauticalDawn",
            "sunriseEnd",
            "sunset",
            "solarNoon",
            "nadir"
          ),
          tz = "UTC"
        )
        
        # bring everything together and bind
        
        single_spp_dets <- cbind(single_spp_dets, time_frame[, 4:ncol(time_frame)])
        
        
        
        
        
        
        # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
        #Morning onset: time of first detection - local sunrise ####
        # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
        
        first_onset <- single_spp_dets[date_time >= nadir &
                                         date_time < solarNoon, ]
        if (nrow(first_onset) != 0) {
          # store the earliest detection by station_date
          first_onset[, min_time_det := min(date_time), .(station_date)]
          first_onset[, first_onset := int_length(interval(sunrise, min_time_det)) /
                        60, .(station_date)]
          first_onset <- first_onset[!duplicated(station_date), .(first_onset, station_date)]
          setkey(first_onset, station_date)
          first_onset[, category := "first_onset"]
          setnames(first_onset, old = 'first_onset', new = 'value')
        } else{
          first_onset <- data.table(
            value = NA,
            station_date = NA,
            category = "first_onset"
          )
        }
        
        # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
        #Morning median: time of 50% detection - local sunrise ####
        # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
        # median activity
        med_voc <- single_spp_dets[date_time >= nadir &
                                     date_time < solarNoon, ]
        if (nrow(med_voc) != 0) {
          med_voc[, med_voc := quantile(date_time, probs = 0.5), .(station_date)]
          med_voc <- med_voc[, int_length(interval(sunrise, med_voc)) /
                               60, .(station_date)]
          setnames(med_voc, old = "V1", new = 'med_voc')
          med_voc <- med_voc[!duplicated(station_date), .(med_voc, station_date)]
          setkey(med_voc, station_date)
          med_voc[, category := "median_dawn"]
          setnames(med_voc, old = 'med_voc', new = 'value')
        } else{
          med_voc <- data.table(
            value = NA,
            station_date = NA,
            category = "median_dawn"
          )
        }
        
        
        # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
        #Evening cessation: time of last detection - local sunset ####
        # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
        
        ev_ces <- single_spp_dets[date_time >= solarNoon &
                                    date_time < nadir, ]
        if (nrow(ev_ces) != 0) {
          ev_ces[, max_time_det := max(date_time), by = station_date]
          ev_ces[, ev_ces := int_length(interval(sunset, max_time_det)) /
                   60, by = station_date]
          ev_ces <- ev_ces[!duplicated(station_date), .(ev_ces, station_date)]
          setkey(ev_ces, station_date)
          ev_ces[, category := "ev_ces"]
          setnames(ev_ces, old = 'ev_ces', new = 'value')
        } else{
          ev_ces = data.table(
            value = NA,
            station_date = NA,
            category = "ev_ces"
          )
        }
        
        
        # bring together individual calculations
        out <- rbindlist(l = list(first_onset, med_voc, ev_ces))
        out <- out[!is.na(station_date), ] # throw out measures we couldn't calculate
        if (nrow(out) == 0) {
          next
        }
        out[, common_name := f, ] #add species name to out
        setkey(out, station_date)
        out <- merge(out, single_spp_dets[!duplicated(station_date), .(
          scientific_name,
          date_time,
          date,
          week,
          latitude,
          longitude,
          station_date,
          station_id
        )])
        # drop station_date grouping variable
        out <- out[, !("station_date"), with = FALSE]
        species_holder[[species_counter]] <- out
        
      } #species
      species_holder <- rbindlist(species_holder)
      # make sure directory exists
      ifelse(!dir.exists(file.path(
        here('data/L0/activity_measures/diurnal')
      )), dir.create(file.path(
        here('data/L0/activity_measures/diurnal')
      )), FALSE)
      # write file to directory
      fwrite(
        species_holder,
        file = paste0(
          here('data/L0/activity_measures/diurnal'),
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
      
    } # detection filter
    
  } #months
  
} #continents
