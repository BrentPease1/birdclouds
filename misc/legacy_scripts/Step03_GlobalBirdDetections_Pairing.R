#################################################################################
### Gilbert X Pease Joint Lab Project: Bird-Cloud Analysis
### Step 03: Re-join BirdWeather vocal detection data and compute vocal activity.
### Overview: Join vocal detection data back to station data, process it, pair 
### light data to detection times, compute vocal activity periods.
#################################################################################

#################################################################################
### STEP03 A: Logistics and getting started.
#################################################################################

## Clear workspace and clean up memory:
rm(list=ls())
gc(reset=TRUE)

## Load libraries:
library(sf)
library(move2)
library(ggplot2)
library(here)
library(data.table)
library(lubridate)
library(suncalc)
library(lutz)
library(sf)
library(activity)
library(stringr)
library(tidyr)
library(dplyr)
setDTthreads(0)


## Read in data:

#All station data, to pull station type variable back in:
all.stations <- read.csv("Data/ProcessedData/all.stations.Feb.18.26.csv")
all.stations <- all.stations |>
   dplyr::select(-Latitude, -Longitude) |>
   janitor::clean_names() |>
   distinct()

#Stations that underlie analysis, stations for which to load in observational data:
 stationary.stations <- read.csv("Data/ProcessedData/stationary.stations.BirdCloud.Feb.18.26.csv") #1876 stations here.

#All BirdWeather observational data of vocalizations per species/station (initially
#read in in Step01):
obs <- fread("Data/ProcessedData/all.observations.Feb.18.26.csv") 


################################################################################
### Step 03 B: Process station data a bit more, then re-join detections to 
### stations of interest (stationary stations that are not certain station types)
################################################################################

#First, station_type not always available, so replace_na with a placeholder:
all.stations <- all.stations |>
   dplyr::mutate(station_type = replace_na(station_type, "notavail"))

#Check that the station_type variable changed:
types <- unique(all.stations$station_type)

#Remove station types we know are not reasonable from all stations:
all.stations <- all.stations |>
   dplyr::filter(!(station_type == "stream_audio" | station_type == "stream_youtube"))

#Check that the station_type variable changed again:
types <- unique(all.stations$station_type)

#Join all station data to stationary stations to grab the station_type variable:
stations <- dplyr::right_join(all.stations, stationary.stations)


## Now, remove station-type variable (not needed anymore) and take only one station 
## name coordinate group (some stations are duplicated in above table because of
## differing station_type assignments):
stations <- stations |>
   dplyr::select(station, station_lon, station_lat) |>
   dplyr::distinct() #1876 stationary stations, as we would expect from prev. step


## From all observational data, take only the bird observations for the selected 
## stationary stations:
station_obs <- dplyr::right_join(obs, stations, by="station") #~161 million observations.

station_num <- station_obs |>
   dplyr::select(station) |>
   dplyr::distinct() #Good, this is 1876 stations, as it should be. 

#Write out the file:
write.csv(station_obs, "Data/ProcessedData/stationary.stat.detects.Feb.23.26.csv", row.names = FALSE)


################################################################################
### Step03 C: Process the Observational Data -- subsetting needs and prep for 
### light data.
################################################################################

## Read in data (if jumping to this step):
station_obs <- fread("Data/ProcessedData/stationary.stat.detects.Feb.23.26.csv")


## Rename dataframe and columns (to align better with Brent's naming):
bw <- station_obs
colnames(bw)

setnames(bw, old = c("station_lon", "station_lat"), new = c("lon", "lat"))
colnames(bw)


## Subset Birdweather data to those observations with at least 75% confidence in
## species ID:
bw <- bw |>
  dplyr::filter(confidence >= 0.75) # ~101 million observations


## Prep the BirdWeather timestamp data:

# initial prep of bw timestamps
bw[, timestamp := ymd_hms(timestamp, tz = 'UTC')]
bw <- bw[!is.na(timestamp), ] # 916 fail to parse
bw[, date := date(timestamp)]
bw[, week := week(timestamp)]
colnames(bw)

# get grouping variables
bw[, station_date := .GRP, .(lon, lat, date)]
setkey(bw, station_date)
colnames(bw)


## Process oddball IDs:

#remove noise, mammals, insects, and amphibians:
not_interested <- c("Engine", "Siren", "Coyote", "Dog", 
                    "Eastern Gray Squirrel", "Red Squirrel",
                    "Power tools", "Fireworks", "Gray Wolf", "Gun",
                    "Honey Bee",
                    "Spring Peeper")

total_spp <- bw[!(common_name %in% not_interested), ]

#this should keep frogmouths but drop anuras
total_spp <- total_spp[!(str_detect(common_name, "frog(?!mouth)") | 
                           str_detect(common_name, "Frog(?!mouth)")),]
total_spp <- total_spp[!(common_name %like% "Treefrog"),]
total_spp <- total_spp[!(common_name %like% "Bullfrog"),]
total_spp <- total_spp[!(common_name %like% "Cricket"),]
total_spp <- total_spp[!(common_name %like% "Toad"),]
total_spp <- total_spp[!(common_name %like% "Trig"),]
total_spp <- total_spp[!(common_name %like% "Katydid"),]
total_spp <- total_spp[!(common_name %like% "Chipmunk"),]
total_spp <- total_spp[!(common_name %like% "Conehead"),]
total_spp <- total_spp[!(common_name %like% "Gryllus assimilis"),]
total_spp <- total_spp[!(common_name %like% "Human"),]
total_spp <- total_spp[!(common_name %like% "Monkey"),] # ~100 million observations


## Summarize number of detections. 

#OK, these next lines first calculate how many detections a given species has 
#for each station-date (e.g., raleigh, nc on June 3, 2023). 
total_spp <- total_spp[, .N, by = .(common_name, station_date)]

#I think we need a minimum number of detections for a species to ensure that the 
#samples on that date are representative of the species. Unclear what minimum 
#number should be though. 25 for now.
total_spp <- total_spp[N >= 25, ] #min observations per species per station_date


## Write out files:
write.csv(bw, "Data/ProcessedData/bw_Feb.24.26.csv", row.names=FALSE)
write.csv(total_spp, "Data/ProcessedData/total_spp_Feb.24.26.csv", row.names=FALSE)


################################################################################
### Step03 D: Compute Detection Times, output Vocal Activity files.
################################################################################

## Read in data (if jumping here):
bw <- fread("Data/ProcessedData/bw_Feb.24.26.csv")
total_spp <- fread("Data/ProcessedData/total_spp_Feb.24.26.csv")


## Pull out the species that meet min detection filter:
focal_spp <- total_spp[, unique(common_name)]
focal_spp <- sort(focal_spp)


## Get light data for focal species. Then compute detection times using this. 
## Loop around focal species list. Output vocal_acitivty file.

#Create empty lists to fill:
species_holder <- list()
species_counter = 0

#f <- "Common Redpoll"

#Loop around all species, pulling in sunlight time data (started at 5:29pm):
for(f in focal_spp) {
  
  print(f)
  
  species_counter = species_counter + 1
  single_spp_dets <- bw[common_name == f,]
  
  
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  #Light Data: Extract light data for each sp.
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  
  # now start working on timezone and clocks
  # Generate the sunlight times
  time_frame <- getSunlightTimes(
    data = single_spp_dets[, .(date = date, lon = lon, lat = lat)],
    keep = c("dusk", "night", "dawn", "nightEnd", "sunrise", "nauticalDawn", 
             "sunriseEnd", "sunset", "solarNoon", "nadir"), 
    tz = "UTC")
  
  # bring everything together and bind
  single_spp_dets <- cbind(single_spp_dets, time_frame[, 4:ncol(time_frame)])
  
  
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  #Morning onset: time of first detection - local sunrise ####
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  
  # okay, let's first onset - dawn.
  first_onset <- single_spp_dets[timestamp >= nadir & timestamp < solarNoon, ]
  
  if(nrow(first_onset) != 0) {
    
    # store the earliest detection by station_date
    first_onset[, min_time_det := min(timestamp), .(station_date)]
  
    first_onset[, first_onset := int_length(interval(sunrise, min_time_det))/60, .(station_date)]
  
    first_onset <- first_onset[!duplicated(station_date), .(first_onset, station_date)]
  
    setkey(first_onset, station_date)
  
    first_onset[, category := "first_onset"]
  
    setnames(first_onset, old = 'first_onset', new = 'value')
  
  } else {
  
    first_onset <- data.table(value = NA, station_date = NA, category = "first_onset")
  }
  
  
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  #Morning median: time of 50% detection - local sunrise ####
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  
  # median activity
  med_voc <- single_spp_dets[timestamp >= nadir & timestamp < solarNoon,]
  
  if(nrow(med_voc) != 0) {
    
    med_voc[, med_voc := quantile(timestamp, probs = 0.5), .(station_date)]
    
    med_voc <- med_voc[, int_length(interval(sunrise, med_voc))/60, .(station_date)]
    
    setnames(med_voc, old = "V1", new = 'med_voc')
    
    med_voc <- med_voc[!duplicated(station_date),.(med_voc, station_date)]
    
    setkey(med_voc, station_date)
    
    med_voc[, category := "median_dawn"]
    
    setnames(med_voc, old = 'med_voc', new = 'value')
    
  } else {
    
    med_voc <- data.table(value = NA, station_date = NA, category = "median_dawn")
  }
  
  
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  #Evening cessation: time of last detection - local sunset #
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  
  ev_ces <- single_spp_dets[timestamp >= solarNoon & timestamp < nadir,]
  
  if(nrow(ev_ces) != 0) {
    
    ev_ces[, max_time_det := max(timestamp), by = station_date]
    
    ev_ces[, ev_ces := int_length(interval(sunset, max_time_det))/60, by = station_date]
    
    ev_ces <- ev_ces[!duplicated(station_date), .(ev_ces, station_date)]
    
    setkey(ev_ces, station_date)
    
    ev_ces[, category := "ev_ces"]
    
    setnames(ev_ces, old = 'ev_ces', new = 'value')
    
  } else {
    
    ev_ces <- data.table(value = NA, station_date = NA, category = "ev_ces")
  }
  
  
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  #Aggregate all data.
  # --- # --- # --- # --- # --- # --- # --- # --- # --- # --- 
  
  #bring together individual calculations
  out <- rbindlist(l = list(first_onset, med_voc, ev_ces))
  
  out <- out[!is.na(value), ] #throw out measures we couldn't calculate, NOTE: Bailey changed this to 'value' from 'station_date'
  
  if(nrow(out) == 0){
    
    next
  }
  
  out[, common_name := f,] #add species name to out
  setkey(out, station_date)
  out <- merge(out, single_spp_dets[!duplicated(station_date), .(scientific_name, timestamp, date, week, lat, lon, station_date)])
  #drop station_date grouping variable
  out <- out[, !("station_date"), with = FALSE]
  
  species_holder[[species_counter]] <- out
  
}

species_holder <- rbindlist(species_holder)

write.csv(species_holder, "Data/ProcessedData/vocal_activity_v2_Feb.24.26.csv", row.names=FALSE)

