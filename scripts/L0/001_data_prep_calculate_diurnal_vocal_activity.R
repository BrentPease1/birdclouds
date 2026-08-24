library(here)
library(data.table)
library(lubridate)
library(suncalc)
library(lutz)
library(sf)
library(activity)
library(stringr)
setDTthreads(0)

here::i_am("scripts/L0/001_data_prep_calculate_diurnal_vocal_activity.R")

# functions ####
remove_unwanted_spp <- function(dt) {
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

  like_patterns <- c(
    "Treefrog",
    "Bullfrog",
    "Cricket",
    "Toad",
    "Trig",
    "Katydid",
    "Chipmunk",
    "Conehead",
    "Gryllus assimilis",
    "Human",
    "Monkey"
  )

  dt[
    !(common_name %in% not_interested) &
      !(str_detect(common_name, "[Ff]rog(?!mouth)")) &
      !Reduce(`|`, lapply(like_patterns, function(p) common_name %like% p))
  ]
}
# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# overwrite current files?
overwrite <- T


confidence_cutoff <- c(0.75)
detection_filter <- c(100)
continents <- c(
  "Africa",
  "Asia",
  "Europe",
  "North America",
  "Oceania",
  "South America"
)

# file base name
base <- "E:/bird_acitivity/Results/bird_detections_by_continent_and_month"

# pull in continent shapefile for filtering lat / lon below
continent_shapes <- spData::world

# for looping through file names
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
months[,
  year := fcase(
    str_detect(name, "^\\d{4}") , as.integer(str_sub(name, 1, 4))                        ,
    str_detect(name, "\\d{4}$") , as.integer(str_extract(name, "\\d{4}$"))               ,
    str_detect(name, "\\d{2}$") , as.integer(paste0("20", str_extract(name, "\\d{2}$")))
  )
]


## Create empty lists to fill with data as it's read in:
## first one holds months by continent, second combines continents
results_list <- list(list())

results_list_continent <- list(list())

# debugging helpers
c <- 'Europe'
m <- 4

for (c in continents) {
  print(c)

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

    # extract date and a few helper columns
    bw[, `:=`(
      datetime = lubridate::ymd_hms(timestamp, tz = "UTC"),
      date = lubridate::as_date(timestamp),
      continent = c,
      year = months[m, year]
    )]
    # throw out failures
    bw <- bw[!is.na(datetime)]
    # a couple more helpers
    bw[, `:=`(
      week = week(datetime),
      month = month(date),
      night_id = lubridate::mday(date)
    )]

    # CHECKING STATION ACTIVITY THROUGHOUT DAY
    # IS STATION OPERATING? e.g., Can we trust
    # activity calculations?
    station_dates <- unique(bw[, .(station_id, date, latitude, longitude)])

    old_tz_main <- Sys.getenv("TZ")
    Sys.setenv(TZ = "UTC")
    sun_times <- getSunlightTimes(
      data = station_dates[, .(date, lat = latitude, lon = longitude)],
      keep = c("sunrise", "solarNoon", "sunset")
    )
    if (old_tz_main == "") {
      Sys.unsetenv("TZ")
    } else {
      Sys.setenv(TZ = old_tz_main)
    }

    station_dates <- cbind(
      station_dates,
      setDT(sun_times)[, .(sunrise, solarNoon, sunset)]
    )

    # join back to bw on station_id + date only
    bw <- merge(
      bw,
      station_dates,
      by = c("station_id", "date", "latitude", "longitude")
    )

    # must have detections within 2hrs of sunrise AND later in the day AND afternoon
    bw[,
      has_dawn_dets := any(
        datetime >= (sunrise - 2 * 3600) & datetime < (sunrise + 2 * 3600)
      ),
      .(station_id, date)
    ]
    bw[,
      has_daytime_dets := any(datetime >= sunrise & datetime < solarNoon),
      .(station_id, date)
    ]
    bw[,
      has_evening_dets := any(datetime >= solarNoon & datetime < sunset),
      .(station_id, date)
    ]

    bw <- bw[
      has_dawn_dets == TRUE &
        has_daytime_dets == TRUE &
        has_evening_dets == TRUE,
    ]

    # OLD TRIES AT DOING THIS

    # # split day into e.g. 2-hour bins, count how many bins have detections
    # bw[, hour_bin := floor(hour(datetime) / 2), .(station_id, date)]
    # bw[, n_active_bins := uniqueN(hour_bin), .(station_id, date)]
    #
    # # require active in at least X of 12 possible 2-hr bins
    # bw[n_active_bins >= 8, ]
    #
    #
    # # how long was station running that day?
    # bw[, det_window_hrs := as.numeric(difftime(max(datetime), min(datetime), units = "hours")),
    #    .(station_id, date)]

    # drop off those
    # cut_off <- bw[, quantile(det_window_hrs,.25)]
    # cut_off <- 16
    # bw <- bw[det_window_hrs >= cut_off, ]

    # filter birdnet confidence score
    bw <- bw[confidence >= confidence_cutoff, ]

    # filter down to continent
    # traveling pucs, etc cause issues
    # trying to make it faster for big continent months like EU and NA.
    target_continent <- continent_shapes[continent_shapes$continent == c, ]
    target_continent <- st_simplify(target_continent, dTolerance = 0.1)

    bbox <- st_bbox(target_continent)
    bw_sub <- bw[
      longitude >= bbox["xmin"] &
        longitude <= bbox["xmax"] &
        latitude >= bbox["ymin"] &
        latitude <= bbox["ymax"],
    ]

    # the above is probably good enough
    # tmp <- st_as_sf(bw_sub, coords = c("longitude", "latitude"), crs = 4326)
    # bw <- bw_sub[lengths(st_intersects(tmp, target_continent)) > 0, ]
    # rm(tmp, bw_sub)

    # get grouping variables
    # bw[, station_date := .GRP, .(station_id, date)]
    # setkey(bw, station_date)

    # remove spp we don't care about, function at top
    bw <- remove_unwanted_spp(bw)

    # count the detections per spp per station-date
    total_spp <- bw[, .N, by = .(common_name, species_id, station_id)]

    total_spp <- total_spp[N > detection_filter, ] #min observations per species per station_date
    focal_spp <- total_spp[, unique(common_name)]
    focal_spp <- sort(focal_spp)

    species_holder <- list()
    species_counter <- 0
    for (f in focal_spp) {
      species_counter <- species_counter + 1
      single_spp_dets <- bw[common_name == f, ]

      # grab sunset and sunrise time
      # NOTE: Force TZ=UTC to avoid suncalc DST bug on system-local DST days
      old_tz_main <- Sys.getenv("TZ")
      Sys.setenv(TZ = "UTC")

      # now start working on timezone and clocks
      # Generate the sunlight times
      time_frame <- getSunlightTimes(
        data = single_spp_dets[, .(
          date = date,
          lat = latitude,
          lon = longitude
        )],
        keep = c(
          "nadir"
        )
      )
      if (old_tz_main == "") {
        Sys.unsetenv("TZ")
      } else {
        Sys.setenv(TZ = old_tz_main)
      }

      time_frame <- setDT(time_frame)
      # bring everything together and bind

      single_spp_dets <- cbind(
        single_spp_dets,
        time_frame[, 4:ncol(time_frame)]
      )

      # add a next day nadir
      single_spp_dets[, nadir2 := nadir + 24 * 60 * 60]

      # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
      #Morning onset: time of first detection - local sunrise ####
      # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---

      first_onset <- single_spp_dets[
        datetime >= nadir &
          datetime < solarNoon,
      ]
      if (nrow(first_onset) != 0) {
        # store the earliest detection by station_date
        first_onset[, min_time_det := min(datetime), .(station_id, date)]
        first_onset[,
          first_onset := int_length(interval(sunrise, min_time_det)) /
            60,
          .(station_id, date)
        ]
        first_onset <- first_onset[
          !duplicated(station_id, date),
          .(first_onset, station_id, date)
        ]
        setkey(first_onset, station_id)
        first_onset[, category := "first_onset"]
        setnames(first_onset, old = 'first_onset', new = 'value')
      } else {
        first_onset <- data.table(
          value = NA,
          station_id = NA,
          date = NA,
          category = "first_onset"
        )
      }

      # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
      #Morning median: time of 50% detection - local sunrise ####
      # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
      # median activity
      med_voc <- single_spp_dets[
        datetime >= nadir &
          datetime < solarNoon,
      ]
      if (nrow(med_voc) != 0) {
        med_voc[,
          med_voc := quantile(datetime, probs = 0.5),
          .(station_id, date)
        ]
        med_voc <- med_voc[,
          int_length(interval(sunrise, med_voc)) /
            60,
          .(station_id, date)
        ]
        setnames(med_voc, old = "V1", new = 'med_voc')
        med_voc <- med_voc[
          !duplicated(station_id, date),
          .(med_voc, station_id, date)
        ]
        setkey(med_voc, station_id)
        med_voc[, category := "median_dawn"]
        setnames(med_voc, old = 'med_voc', new = 'value')
      } else {
        med_voc <- data.table(
          value = NA,
          station_id = NA,
          date = NA,
          category = "median_dawn"
        )
      }

      # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---
      #Evening cessation: time of last detection - local sunset ####
      # --- # --- # --- # --- # --- # --- # --- # --- # --- # ---

      ev_ces <- single_spp_dets[
        datetime >= solarNoon &
          datetime < nadir2,
      ]
      if (nrow(ev_ces) != 0) {
        ev_ces[, max_time_det := max(datetime), by = .(station_id, date)]
        ev_ces[,
          ev_ces := int_length(interval(sunset, max_time_det)) /
            60,
          by = .(station_id, date)
        ]
        ev_ces <- ev_ces[
          !duplicated(station_id, date),
          .(ev_ces, station_id, date)
        ]
        setkey(ev_ces, station_id)
        ev_ces[, category := "ev_ces"]
        setnames(ev_ces, old = 'ev_ces', new = 'value')
      } else {
        ev_ces <- data.table(
          value = NA,
          station_id = NA,
          date = NA,
          category = "ev_ces"
        )
      }

      # bring together individual calculations
      out <- rbindlist(l = list(first_onset, med_voc, ev_ces))
      out <- out[!is.na(station_id), ] # throw out measures we couldn't calculate
      if (nrow(out) == 0) {
        next
      }
      out[, common_name := f, ] #add species name to out
      setkey(out, station_id)
      out <- merge(
        out,
        single_spp_dets[
          !duplicated(station_id, date),
          .(
            scientific_name,
            datetime,
            date,
            week,
            latitude,
            longitude,
            station_id
          )
        ],
        by = c("station_id", "date")
      )
      # drop station_date grouping variable
      # out <- out[, !("station_date"), with = FALSE]
      species_holder[[species_counter]] <- out
    } #species
    species_holder <- rbindlist(species_holder)
    # make sure directory exists
    ifelse(
      !dir.exists(file.path(
        here('data/L0/activity_measures/diurnal')
      )),
      dir.create(file.path(
        here('data/L0/activity_measures/diurnal')
      )),
      FALSE
    )
    # write file to directory
    fwrite(
      species_holder,
      file = paste0(
        here('data/L0/activity_measures/diurnal'),
        "/activity_measures_",
        c,
        "_",
        this_month,
        "_conf_",
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
  } #months
} #continents
