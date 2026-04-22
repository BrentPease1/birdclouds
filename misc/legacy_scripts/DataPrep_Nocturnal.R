#################################################################################
### Gilbert X Pease Joint Lab Project: Bird-Cloud Analysis
###  - Nocturnal Data -
###   > In previous steps, we have downloaded Raw BirdWeather data for years 
###     between 2023 and 2025. 
###   > We then processed that data at the staion level to determine which of 
###     the BirdWeather station locations represent stationary recording units. 
###   > For these 'stationary stations' we then joined the species-level vocal 
###     detection data back to these sites.
###   > Now, this script will (1) identify which of these sp are 'nocturnal' and 
###     retain these, (2) determine the vocal activity period of these noctural
###     sp across sites/dates - answering the Q of does sp x vocalize at night 
###     y (date) at site z (station coords) and, if yes, how often?, (3) before
###     re-joining light data to determine the night start and night end times
###     for all sp/date/locations preserved.
###   > The outputted data-frame will house all species of noctural species that
###     vocalize at night and the dates/sites/night times of these detections.
###     Later, weather data for cloud cover at these detection sites will be
###     joined for the analysis.
#################################################################################


#################################################################################
### Logistics and getting started.
#################################################################################

## Clear workspace and clean up memory:
rm(list=ls())
gc(reset=TRUE)


## Load libraries:
library(data.table)
library(dplyr)
library(suncalc)
library(stringr)
library(taxize)
library(tidyr)


## Read in data:

#All BirdWeather detections at stationary stations:
detections <- fread("Data/ProcessedData/stationary.stat.detects.Feb.23.26.csv") 

#Elton traits database:
traits <- read.delim("Data/NocturnalData/elton.txt") |> 
  dplyr::select(scientific_name = Scientific, 
                english = English, 
                nocturnal = Nocturnal)

#Nocturnal species (first calculated below):
nocturnal_spp <- fread("Data/NocturnalData/spp_nocturnal.csv") |>
  dplyr::select(common_name,
                scientific_name = sci_name_bw)


#################################################################################
### Identify nocturnal species, target of analysis.
#################################################################################

## Subset detection dataframe read in above to unique species names:
all_sp <- detections |> 
  dplyr::select(common_name, scientific_name) |>
  dplyr::distinct()


## Remove oddball IDs from all_sp dataframe:
not_interested <- c("Engine", "Siren", "Coyote", "Dog", 
                    "Eastern Gray Squirrel", "Red Squirrel",
                    "Power tools", "Fireworks", "Gray Wolf", "Gun",
                    "Honey Bee",
                    "Spring Peeper")

sp <- all_sp[!(common_name %in% not_interested), ]

sp <- sp[!(str_detect(common_name, "frog(?!mouth)") | 
                           str_detect(common_name, "Frog(?!mouth)")),]
sp <- sp[!(common_name %like% "Treefrog"),]
sp <- sp[!(common_name %like% "Bullfrog"),]
sp <- sp[!(common_name %like% "Cricket"),]
sp <- sp[!(common_name %like% "Toad"),]
sp <- sp[!(common_name %like% "Trig"),]
sp <- sp[!(common_name %like% "Katydid"),]
sp <- sp[!(common_name %like% "Chipmunk"),]
sp <- sp[!(common_name %like% "Conehead"),]
sp <- sp[!(common_name %like% "Gryllus assimilis"),]
sp <- sp[!(common_name %like% "Human"),]
sp <- sp[!(common_name %like% "Monkey"),] 


## Process the names retained (according to ALAN repo steps, all/exact 
## justifications unknown):

#Two species with two scientific names in BirdWeather, fix:
sp <- sp |>
  dplyr::mutate(scientific_name = ifelse(scientific_name == "Falcipennis canadensis", 
                                         "Canachites canadensis", scientific_name),
                scientific_name = ifelse(scientific_name == "Glossopsitta porphyrocephala", 
                                         "Parvipsitta porphyrocephala", scientific_name))

#More to filter out:
spp <- sp |> 
  dplyr::select(common_name, scientific_name) |> 
  dplyr::distinct() |> 
  dplyr::filter(! (common_name == "Greater Whitethroat" & scientific_name == "Curruca communis")) |> 
  dplyr::filter(! (common_name == "Lesser Whitethroat" & scientific_name == "Curruca curruca")) |> 
  dplyr::filter(! (common_name == "Leach's Storm-Petrel" & scientific_name == "Hydrobates leucorhous")) |> 
  dplyr::filter(! ( grepl("Fox Sparrow", common_name) & scientific_name != "Passerella iliaca"))

#Basic join of BirdWeather data and Elton traits by BirdWeather scientific name:
spp_trait <- spp |> 
  dplyr::left_join(traits)

#Separate out species joined above:
spp_trait_elton <- spp_trait |> 
  dplyr::filter(!is.na(nocturnal)) |> 
  dplyr::mutate(sci_name_bw = scientific_name, 
                sci_name_elton = scientific_name) |> 
  dplyr::select(-scientific_name)

#Search for species synonyms for the species that failed to join on BirdWeather
#scientific name:
spp_syn <- spp |> 
  dplyr::left_join(traits) |> 
  dplyr::filter(is.na(nocturnal))

syn_list <- taxize::synonyms(spp_syn$scientific_name, db = "itis")

temp <- taxize::synonyms_df(syn_list) |> 
  tibble::as_tibble() |>
  dplyr::select(scientific_name = .id, 
                sci_name_syn = syn_name) |> 
  dplyr::distinct() |> 
  tidyr::separate(sci_name_syn, into = c("genus", "sp", "subsp"), sep = " ") |> 
  dplyr::select(-subsp) |> 
  dplyr::mutate(sci_name_syn = paste(genus, sp)) |> 
  dplyr::select(-genus, -sp) |> 
  dplyr::distinct()

#Save the synonym dataframe:
fwrite(temp, "Data/NocturnalData/taxize_scientific_synonyms.csv")

#Get an extra 170 species with the itis synonyms:
trait_data <- synonyms_df(syn_list) |> 
  tibble::as_tibble() |>
  dplyr::select(scientific_name = .id, 
                sci_name_syn = syn_name) |> 
  dplyr::distinct() |> 
  tidyr::separate(sci_name_syn, into = c("genus", "sp", "subsp"), sep = " ") |> 
  dplyr::select(-subsp) |> 
  dplyr::mutate(sci_name_syn = paste(genus, sp)) |> 
  dplyr::select(-genus, -sp) |> 
  dplyr::distinct() |>
  dplyr::left_join(spp) |> 
  dplyr::select(common_name, 
                sci_name_bw = scientific_name, 
                scientific_name = sci_name_syn) |> 
  dplyr::left_join(traits) |> 
  dplyr::filter(!is.na(nocturnal)) |> 
  dplyr::select(common_name, sci_name_bw = sci_name_bw, sci_name_elton = scientific_name, nocturnal)

#Join:
trait_data_more <- full_join(spp_trait_elton, trait_data)

#Now join on common name:
elton_common_name_join <- anti_join(spp, trait_data_more) |> 
  dplyr::left_join(temp) |> 
  dplyr::select(english = common_name, 
                sci_name_bw = scientific_name, 
                sci_name_syn) |> 
  dplyr::left_join(traits) |> 
  dplyr::filter(!is.na(nocturnal)) |> 
  dplyr::select(common_name = english, 
                sci_name_bw, 
                sci_name_elton = scientific_name, 
                nocturnal)

trait_data_more_more <- trait_data_more |> 
  dplyr::full_join(elton_common_name_join) |> 
  dplyr::select(common_name, sci_name_bw, sci_name_elton, nocturnal) 

#Species manually reviewed to get names
manual_review <- fread("Data/NocturnalData/review_species.csv") |>
  dplyr::select(common_name = com_name, 
                scientific_name = sci_name,
                sci_name_manual)

man_review_traits <- manual_review |> 
  dplyr::select(common_name, scientific_name = sci_name_manual) |> 
  dplyr::left_join(traits) |> 
  dplyr::select(common_name, sci_name_elton = scientific_name, nocturnal) |> 
  dplyr::left_join(spp) |> 
  dplyr::select(common_name, sci_name_bw = scientific_name, sci_name_elton, nocturnal)

#Name dataframe:
final_trait <- trait_data_more_more |> 
  dplyr::full_join(man_review_traits) |> 
  dplyr::distinct() |> 
  dplyr::filter(!(common_name == "Pine Warbler" & sci_name_elton == "Vermivora pinus")) |> 
  dplyr::filter(!(common_name == "Purple-crowned Lorikeet" & sci_name_bw == "Parvipsitta porphyrocephala")) |> 
  dplyr::filter(!(common_name == "Spruce Grouse" & sci_name_bw == "Falcipennis canadensis")) |> 
  dplyr::filter(!is.na(sci_name_bw))

fwrite(final_trait, "Data/NocturnalData/spp_name_review.csv")

#Noctural Sp:
nocturnal <- final_trait |>
  dplyr::filter(nocturnal > 0)

fwrite(nocturnal, "Data/NocturnalData/spp_nocturnal.csv")


#################################################################################
### Process the nocturnal species detection data. Join, filter by confidence in
### species ID and minimum number of detections.
#################################################################################

## Subset detection data by nocturnal species:
noc_detections <- detections |>
  dplyr::right_join(nocturnal_spp)


## Filter detection data to those that have a confidence score of at least 0.75 and
## assign a site ID to each station (station, lat, lon):
noc_detections <- noc_detections |>
  dplyr::filter(confidence >= 0.75) |>
  dplyr::mutate(site = dplyr::cur_group_id()) |>
  dplyr::ungroup()


## Break up the timestamp column into its component parts (will need to parse by date):
noc_data <- noc_detections |>
  dplyr::mutate(lat = station_lat, 
                lon = station_lon) |>
  dplyr::mutate(tz = lutz::tz_lookup_coords(lat, lon)) |> 
  dplyr::mutate(timestamp = lubridate::ymd_hms(timestamp, tz = "UTC")) |> 
  dplyr::mutate(time = lubridate::with_tz(timestamp, tzone = tz)) |> 
  dplyr::select(timestamp, time, tz, lat, lon, common_name, 
                scientific_name, confidence, station, site) |> 
  dplyr::mutate(date = lubridate::as_date(time),
                week = lubridate::week(date)) |>
  na.omit() #23 fail to parse and are removed.


## Set a detection filter:

#Create a grouping variable:
noc_data[, station_date := .GRP, .(lon, lat, date)]
setkey(noc_data, station_date)

#Summarize the number of detections of a given species at a given station-date.
#Then set a 'detection filter' to set a miniumu number of detections for a sp, 
#choosing 25 here: 
noc_counts <- noc_data |>
  dplyr::group_by(scientific_name, station_date) |>
  dplyr::summarise(sp_counts_per_day = n()) |>
  dplyr::ungroup() |>
  dplyr::filter(sp_counts_per_day >= 25)


## Re-join detection-data back to detection filter calculations:
noc_filtered <- noc_counts |>
  dplyr::left_join(noc_data) 


## See how many species are preserved post-filter (n = 69):
sp_names <- noc_filtered |>
  dplyr::select(scientific_name) |>
  dplyr::distinct()


## Save out noc_filtered as the nocturnal species/station that will be analyzed:
fwrite(noc_filtered, "Data/NocturnalData/detect_data_nocturnal.csv", row.names = FALSE)


#################################################################################
### Determine when/where these nocturnal species vocalize at night.
#################################################################################  

## Read in noctural detection data (calculated above) if jumping to this step:
noc_detect <- fread("Data/NocturnalData/detect_data_nocturnal.csv") 


## Add sunlight times to data, by location (station) and date, only need sunrise
## and sunset times becuase we consider night as the time from sunrise to sunset:
time_frame <- suncalc::getSunlightTimes(
  data = noc_detect[, .(date = date, lon = lon, lat = lat)],
  keep = c("sunrise", "sunset"), 
  tz = "UTC")

#Bring everything together and bind
noc_detect <- cbind(noc_detect, time_frame[, 4:ncol(time_frame)])


## Determine if detections occur at night (less than sunrise and greater than
## sunset), only keeping detections within this focal time:
night_detect <- noc_detect |>
  dplyr::filter(time < sunrise | time > sunset) |>
  dplyr::mutate(period = "night",
                det_time = time,
                night_start = sunset, 
                night_end = sunrise) |>
  dplyr::select(site, station, lat, lon, week, date, scientific_name, period,
                night_start, night_end) |>
  dplyr::group_by(site, station, lat, lon, week, date, scientific_name, period,
                night_start, night_end) |>
  dplyr::summarise(sp_counts_per_night = n()) |>
  dplyr::ungroup() |>
  dplyr::distinct()


## See how many species are preserved, i.e. how many of the nocturnal sp are
## detected by BirdWeather stations at night (n = 67):
sp_names <- night_detect |>
  dplyr::select(scientific_name) |>
  dplyr::distinct()


## Save out data:
fwrite(night_detect, "Data/NocturnalData/detect_data_nocturnal_night.csv", row.names=FALSE)


#################################################################################
### Use above data steps to finalize a list of sp/site/dates to analyze, 
### preserving actual detections and plausible site/date detections with 0 records.
#################################################################################

## Read in data (if jumping here):

#Nocturnal detection data from all 24 hr (without night filter):
noc_detect <- fread("Data/NocturnalData/detect_data_nocturnal.csv") 

#Nocturnal detection data at night (with night filter):
night_detect <- fread("Data/NocturnalData/detect_data_nocturnal_night.csv") 


## Determine list of unique species detected at any site:
sp.names <- unique(night_detect$scientific_name) #67 sp.

#name <- "Aegolius acadicus" #test


## Write function to pull out sp-specific data for each name in names, to aggregate
## all combos of sp/site/date for which we'll analyze:
sp.site.date <- function(name) {
  
  print(name)
  
  ## All possible combos:
  
  #Determine all unique sp/site/week/DATE combos across 24hr day from which a 
  #sp was detected any time that day to determine all possible detection sites
  #that we will need/want to account for, for one sp at a time: 
  template <- noc_detect |>
    dplyr::filter(scientific_name == name) |>
    dplyr::group_by(scientific_name, site, station, lat, lon, week) |>
    dplyr::distinct() |>
    dplyr::summarise(min_date = min(date), 
                     max_date = max(date)) |>
    dplyr::ungroup() |>
    dplyr::rowwise() |>
    dplyr::mutate(date = list(seq(from = min_date, to = max_date, by = "day"))) |> 
    unnest(cols="date") |>
    dplyr::mutate(week = lubridate::week(date)) |> 
    dplyr::cross_join(tibble(period = "night")) |>
    dplyr::select(scientific_name, site, station, lat, lon,  week, date, period) |>
    dplyr::distinct() 
  
  template$date <- as.Date(template$date)
  
  
  ## Known detections:
  
  #Determine all instances of a species recorded at a site duirng a period of
  #interest, sunrise or solar noon). sp.obs comes from the solar-paritioned 
  #detection data, all species detected at time periods of interest (sunrise,
  #solar noon) and the locations where they occur (sites) and how many of detections
  #of that sp were detected there/then (sp_counts_per_period).
  sp.obs <- night_detect |>
    dplyr::filter(scientific_name == name)
  
  sp.obs$date <- as.Date(sp.obs$date)
  
  ## Paired data (preserving zeros):
  
  #Template indicates all possible siteXspeciesXdateXperiod detections
  #Sp.obs indicates all known siteXspeciesXdateXperiod detections (and the sum)
  #Combining the two dataframes to fill in those sites/dates/periods that have
  #zero detections.
  sp.data <- template |>
    dplyr::full_join(sp.obs) |>
    dplyr::select(scientific_name, site, station, lat, lon, week, date, period,
                  night_start, night_end, sp_counts_per_night) |>
    dplyr::mutate(sp_counts_per_night = replace_na(sp_counts_per_night, 0)) 
  
  
  ## Return table:
  return(sp.data)
  
}

#Check to make sure function is working:
n <- sp.site.date("Ninox connivens") #Yes!
o <- sp.site.date("Otus sunia") #Yes!


## Create an empty list to fill with sp-specific data and loop function around
## all names:
all.sp <- c()

for(sp in sp.names) {
  one.sp <- sp.site.date(sp)
  all.sp <- rbind(all.sp, one.sp)
}


#################################################################################
### Clean up outputted data to add in missing cells for night start and end.
#################################################################################

## Cleaning up outputted data to add in night start and end times to those 
## station/date combos that have zero detections preserved:

#Pull out zero-detect sites:
zero_sites <- all.sp |>
  dplyr::filter(sp_counts_per_night == 0) 


#Add sunlight time to data, by site and date:
sun_zero_sites <- zero_sites |> 
  dplyr::select(site, station, lat, lon) |>
  dplyr::cross_join(tibble(date = seq(from = min(all.sp$date), 
                                      to = max(all.sp$date), 
                                      by = 1))) |> 
  dplyr::mutate(tz = lutz::tz_lookup_coords(lat, lon)) |>
  distinct() 

#Pull out only sunrise and solarNoon data:
res_zero_sites <- suncalc::getSunlightTimes(
  data = sun_zero_sites, 
  keep = c("sunrise", "sunset")) |>
  distinct()

res_zero_sites_df <- sun_zero_sites |>
  dplyr::left_join(res_zero_sites) |>
  dplyr::mutate(sunrise = lubridate::with_tz(sunrise, tzone = tz), 
                sunset = lubridate::with_tz(sunset, tzone = tz)) |>
  dplyr::mutate(period = "night",
                night_start = sunset,
                night_end = sunrise)

zero_data <- all.sp |>
  dplyr::right_join(res_zero_sites_df) |>
  dplyr::select(-tz, -sunrise, -sunset)


## Write out analytical data for nocturnal sp:
fwrite(zero_data, "Data/NocturnalData/nocturnal_activity.csv", row.names=FALSE)
