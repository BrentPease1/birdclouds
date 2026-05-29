################################################################################
### Gilbert X Pease - Bird Cloud Project - Processing Data for Analysis
################################################################################

### Install Packages, Clean up Workspace, Load Libraries:

# #Install devtools if not available
# if(!"remotes" %in% installed.packages()[,"Package"]) install.packages("remotes")
#
# #Install traitdata package from Github
# remotes::install_github("RS-eco/traitdata", build_vignettes = T, force=T)
#
# #Install birdweatheR package from Github
# devtools::install_github("BrentPease1/birdweatheR")

#Clear workspace and clean up memory:
rm(list = ls())
gc(reset = TRUE)

#Load libraries:
library(sf)
library(traitdata)
library(dplyr)
library(data.table)
library(tidyverse)
library(birdweatheR)
library(here)
birdweatheR::connect_birdweather()


### Read in Data:

#Trait data (will grab Family, activity period):
elton <- traitdata::elton_birds

#Analysis data:
load(here("data", "L2", "final_nocturnal.RData"))
load(here("data", "L2", "final_diurnal_first_onset.RData"))
load(here("data", "L2", "final_diurnal_ev_ces.RData"))


### Add some BirdWeather data back to datasets (nocturnal: sci_name and sp_id;
### diurnal: sp_id).

#Determine names to loop over:
noc_com <- unique(final_nocturnal$common_name)

c <- final_nocturnal |>
  dplyr::select(common_name) |>
  dplyr::distinct()

#Loop through list of names and grab BirdWeathe info:
noc_bw <- list(list())

for (sp in noc_com) {
  bw <- birdweatheR::find_species(sp)

  noc_bw[[sp]] <- bw
}

noc_bw <- rbindlist(noc_bw)

noc_bw <- noc_bw |>
  dplyr::distinct()

#Join back to broader dataset:
noc <- dplyr::left_join(final_nocturnal, noc_bw)


#Determine names to loop over:
diurn_on_com <- unique(final_diurnal_first_onset$common_name)

#Loop through list of names and grab BirdWeathe info:
diurn_on_bw <- list(list())

for (sp in diurn_on_com) {
  bw <- birdweatheR::find_species(sp)

  diurn_on_bw[[sp]] <- bw
}

diurn_on_bw <- rbindlist(diurn_on_bw)

diurn_on_bw <- diurn_on_bw |>
  dplyr::distinct()

#Join back to broader dataset:
diurn_on <- dplyr::left_join(final_diurnal_first_onset, diurn_on_bw)

#Determine names to loop over:
diurn_ev_com <- unique(final_diurnal_ev_ces$common_name)

#Loop through list of names and grab BirdWeathe info:
diurn_ev_bw <- list(list())

for (sp in diurn_ev_com) {
  bw <- birdweatheR::find_species(sp)

  diurn_ev_bw[[sp]] <- bw
}

diurn_ev_bw <- rbindlist(diurn_ev_bw)

diurn_ev_bw <- diurn_ev_bw |>
  dplyr::distinct()

#Join back to broader dataset:
diurn_ev <- dplyr::left_join(final_diurnal_ev_ces, diurn_ev_bw)


### Set a detection threshold. Determine minimum number of sites a species must
### occur at to remain in the analysis. nsite = 30.

# nocturnal w/ site filter
noc <- noc |>
  dplyr::group_by(species_id) |>
  dplyr::mutate(nsite = length(unique(station_id))) |>
  dplyr::ungroup() |>
  dplyr::filter(nsite > 30)

# diurnal onset w/ site filter
diurn_on <- diurn_on |>
  dplyr::group_by(species_id) |>
  dplyr::mutate(nsite = length(unique(station_id))) |>
  dplyr::ungroup() |>
  dplyr::filter(nsite > 30)

# diurnal ev w/ site filter
diurn_ev <- diurn_ev |>
  dplyr::group_by(species_id) |>
  dplyr::mutate(nsite = length(unique(station_id))) |>
  dplyr::ungroup() |>
  dplyr::filter(nsite > 30)


### Join all nocturnal and diurnal sp occurrences into one dataset, with one sp
### represented each:
noc_names <- noc |>
  dplyr::select(species_id, common_name, scientific_name) |>
  dplyr::distinct()

diurn_on_names <- diurn_on |>
  dplyr::select(species_id, common_name, scientific_name) |>
  dplyr::distinct()

diurn_ev_names <- diurn_ev |>
  dplyr::select(species_id, common_name, scientific_name) |>
  dplyr::distinct()

diurn_names <- rbind(diurn_on_names, diurn_ev_names) |>
  dplyr::distinct()

sp_names <- rbind(noc_names, diurn_names) |>
  dplyr::distinct() |>
  dplyr::mutate(common_name_bw = common_name) #Indicate which dataset this name came from.


### Assign activity period (nocturnal or diurnal) to name data, to confirm each
### team is only analyzing those birds that are nocturnal or diurnal. Also assign
### 'Family' to datasets. Assign both features/traits using the Elton Traits
### dataset.

## Pull out only the traits needed, aligning column names to match each other and
## dataframe 'source':
elton_traits <- elton |>
  dplyr::select(
    family = Family,
    common_name_el = English,
    nocturnal = Nocturnal,
    scientific_name = scientificNameStd
  )


## First, join by scientific_name.

#join trait data to name data, based on scientific name:
sp_traits <- left_join(
  sp_names,
  elton_traits,
  by = join_by(scientific_name == scientific_name)
)

#Assign an 'activity period' column to dataframe:
sp_traits <- sp_traits |>
  dplyr::mutate(
    activity_period = ifelse(nocturnal == 0, "diurnal", "nocturnal")
  )

#Determine how many sci and/or com names didn't join, which we'll need to
#manually review/assign to 'nocturnal' or 'diurnal':
to_assess <- sum(is.na(sp_traits$activity_period)) #55 species


## Next, join by common_name, to fill in activity_period NAs above.

# Step 1: split into matched vs unmatched
matched = sp_traits |> dplyr::filter(!is.na(nocturnal))
unmatched = sp_traits |> dplyr::filter(is.na(nocturnal))

# Step 2: try to recover unmatched using common name
recovered = unmatched |>
  dplyr::select(
    -family,
    -scientific_name,
    -common_name_el,
    -nocturnal,
    -activity_period
  ) |>
  dplyr::left_join(elton_traits, by = c("common_name_bw" = "common_name_el")) |>
  dplyr::rename(common_name_el = common_name_bw) |> #Rename because the common_name that the join happens on is from elton
  dplyr::mutate(common_name = common_name_el) #Create just a 'common_name' column

# Step 3: recombine
sp_traits_final = dplyr::bind_rows(matched, recovered)

# Step 4: assign activity period, write out sp_traits_final
sp_traits_final = sp_traits_final |>
  dplyr::mutate(
    activity_period = ifelse(nocturnal == 0, "diurnal", "nocturnal")
  )

# Step 5: check what's still missing
#Scientific names from Birds of the World, researcher knowledge
to_assess = sum(is.na(sp_traits_final$activity_period)) # now 16 missing --> manually fill


## Manually fill in 16 missing joins - to generate "missing_final" dataframe.

# Pull out a dataframe of the missing joins:
to_assess <- sp_traits_final |>
  dplyr::filter(is.na(activity_period))

#Save out and manually fill in:
fwrite(
  to_assess,
  here("data", "L3", "to_assess_manually_May2026.csv"),
  row.names = FALSE
)

# read back in filled out missing, re-join with sp_traits and get one final df
missing_filled = read.csv(here("data", "L3", "to_assess_manually_May2026.csv"))


## Join the datasets.

# clean up (remove multiple common name columns, etc)
sp_traits_clean <- sp_traits_final |>
  dplyr::select(
    species_id,
    family,
    scientific_name,
    common_name,
    nocturnal,
    activity_period
  )

missing_clean <- missing_filled |>
  dplyr::select(
    species_id,
    family,
    scientific_name,
    common_name,
    nocturnal,
    activity_period
  )

missing_clean$species_id <- as.character(missing_clean$species_id)


#remove 16 missing spp missing (still NA) from the automated data join (sp_traits)
sp_traits_no_missing = sp_traits_clean |>
  na.omit()

#add back in (now filled in)
final_traits = dplyr::bind_rows(sp_traits_no_missing, missing_clean)

#check for NA
sum(is.na(final_traits)) # 0! (yayyy)

# Check duplicates
duplicates <- final_traits |>
  dplyr::count(species_id) |>
  dplyr::filter(n > 1) #11 duplicates

#Drop duplicates, first attempt. By pulling out all distinct records:
final_traits <- final_traits |>
  dplyr::distinct()

# Check duplicates again
duplicates <- final_traits |>
  dplyr::count(species_id) |>
  dplyr::filter(n > 1) #2 duplicates, investigate.

#In both cases, the two remaining duplicates have two different families assigned.
#Manually investigate and correct these. species_id 134 and 179 are duplicated.
#Species_id 134 is the House Finch, according to Cornell Lab of Ornithology this
#is Family Fringillidae. Species_id 179 is Casssin's Finch and is Family
#Fringillidae also according to Cornell. Remove any records that are NOT these
#assignments, filter out:
final_traits <- final_traits |>
  dplyr::filter(!(species_id == 134 & family == "Fringillidae")) |>
  dplyr::filter(!(species_id == 179 & family == "Fringillidae"))

#Again, check for duplicates:
duplicates <- final_traits |>
  dplyr::count(species_id) |>
  dplyr::filter(n > 1) #0 duplicates - good!


### Now, add this activity_period information back into the dataframes for
### analysis.

#Filter analytical dataframes to only those sp that meet either diurnal or
#nocturnal criteria:
noc_data <- dplyr::left_join(noc, final_traits) |>
  dplyr::filter(nocturnal == 1)

sum(is.na(noc_data)) #0, good!

diurn_on_data <- dplyr::left_join(diurn_on, final_traits) |>
  dplyr::filter(nocturnal == 0)

sum(is.na(diurn_on_data)) #0, good!

diurn_ev_data <- dplyr::left_join(diurn_ev, final_traits) |>
  dplyr::filter(nocturnal == 0)

sum(is.na(diurn_ev_data)) #0, good!


#Check number of species represented in each dataset:
noc_sp <- noc_data |>
  dplyr::select(species_id) |>
  dplyr::distinct() #n = 24 sp

diurn_on_sp <- diurn_on_data |>
  dplyr::select(species_id) |>
  dplyr::distinct() #n = 465 sp

diurn_ev_sp <- diurn_ev_data |>
  dplyr::select(species_id) |>
  dplyr::distinct() #n = 436 sp

#Read out the data:
fwrite(noc_data, here("data", "L3", "noc_data.csv"), row.names = FALSE)
fwrite(
  diurn_on_data,
  here("data", "L3", "diurn_on_data.csv"),
  row.names = FALSE
)
fwrite(
  diurn_ev_data,
  here("data", "L3", "diurn_ev_data.csv"),
  row.names = FALSE
)


### Create a grid for random intercept adjustments, for each dataset.

## Read in data:
noc_data <- fread(here("data", "L3", "noc_data.csv"))
diurn_on_data <- fread(here("data", "L3", "diurn_on_data.csv"))
diurn_ev_data <- fread(here("data", "L3", "diurn_ev_data.csv"))


## Ensure each station_id has only one coordinate assigned to it.
## To do this, group by station (station_id), take median of lat lons associated
## with that station to get one med_location for each station and then measure
## distance from median to all unique coordinate pairs. If > 5% of the distances
## are > 500m apart, discard the station_id. If station_id only has one unique
## coordinate pair then just keep this one.

#Write function to evaluate multi-coord station ids:
evaluate_stations <- function(id) {
  print(id)

  #subset to only location data:
  data <- d |>
    dplyr::filter(station_id == id) |>
    dplyr::select(latitude, longitude, station_id) |>
    dplyr::distinct()

  check1 <- nrow(data)

  if (check1 == 1) {
    station_coordinate <- data |>
      dplyr::select(station_id, latitude, longitude)

    print("Station has a single point")
  } else {
    print("Several points, function continues")

    #Find the median coord:
    med_coord <- data |>
      dplyr::mutate(med_lat = median(latitude), med_lon = median(longitude)) |>
      dplyr::select(station_id, med_lat, med_lon)

    #Create sf object from all points:
    data_sf <- st_as_sf(data, coords = c("longitude", "latitude"), crs = 4326)

    med_sf <- st_as_sf(med_coord, coords = c("med_lon", "med_lat"), crs = 4326)

    #calculate distances between all unique coords and med coord:
    dist <- sf::st_distance(data_sf, med_sf, by_element = TRUE)

    #Add distances between med to dataframe of coords, identify which
    #are greater than 500:
    dist_data <- data |>
      dplyr::mutate(distance_to_med = as.numeric(dist)) |>
      dplyr::mutate(too_far = ifelse(distance_to_med > 500, 1, 0))

    #Calculate percentage of stations farther than 500m from median:
    dist_percent <- nrow(dist_data[dist_data$too_far == 1, ]) /
      nrow(dist_data) *
      100

    #if dist_percent is > 5%, remove station_id. If < 5%, keep station_id and
    #assign the median coord as its location:

    check2 <- dist_percent > 5

    if (check2) {
      station_coordinate <- c()

      print("Station coordinates too far apart")
    } else {
      station_coordinate <- med_coord |>
        dplyr::distinct() |>
        dplyr::rename(latitude = med_lat, longitude = med_lon)

      print("Station included, med coordinate assigned.")
    }
  }

  return(station_coordinate)
}


## Evaluate all station_ids (by dataset):

#Diurnal onset:

#Assign dataframe and identify the unique station_ids to loop around:
d <- diurn_on_data

stations <- unique(d$station_id)

#Check function works:
check_fun <- evaluate_stations(4275) #it does!

#Loop around all station_ids:
diurn_on_stations <- c()

for (id in stations) {
  all_stations <- evaluate_stations(id)
  diurn_on_stations <- rbind(diurn_on_stations, all_stations)
}


#Diurnal cessation:

#Assign dataframe and identify the unique station_ids to loop around:
d <- diurn_ev_data

stations <- unique(d$station_id)

#Check function works:
check_fun <- evaluate_stations(4275) #it does!

#Loop around all station_ids:
diurn_ev_stations <- c()

for (id in stations) {
  all_stations <- evaluate_stations(id)
  diurn_ev_stations <- rbind(diurn_ev_stations, all_stations)
}


#Nocturnal:

#Assign dataframe and identify the unique station_ids to loop around:
d <- noc_data

stations <- unique(d$station_id)

#Check function works:
check_fun <- evaluate_stations(4275) #it does!

#Loop around all station_ids:
noc_stations <- c()

for (id in stations) {
  all_stations <- evaluate_stations(id)
  noc_stations <- rbind(noc_stations, all_stations)
}


## Join station coordinate data back to full datasets:
diurn_ev <- diurn_ev_data |>
  dplyr::select(-latitude, -longitude) |>
  dplyr::right_join(diurn_ev_stations)

diurn_on <- diurn_on_data |>
  dplyr::select(-latitude, -longitude) |>
  dplyr::right_join(diurn_on_stations)

noc <- noc_data |>
  dplyr::select(-latitude, -longitude) |>
  dplyr::right_join(noc_stations)


## Remove data no longer needed
rm(
  all_stations,
  check_fun,
  d,
  diurn_ev_data,
  diurn_ev_stations,
  diurn_on_data,
  diurn_on_stations,
  noc_data,
  noc_stations,
  id,
  stations
)


## Create grid for random effects structure:

#Bounding box:
bounding_box <- sf::st_bbox(
  c(xmin = -180, ymin = -90, xmax = 180, ymax = 90),
  crs = sf::st_crs(4326)
)


#Create a global polygon grid with cell_size spacing of 0.5 deg
#NOTE: Group by grid_id and see how many station_ids fall into each.
#More than 1 station per cell. Tried this and the diurnal dataset has a few grid
#cells with only 1 station. Didn't notice much of a difference between the 0.5
#and 1 degree grid, so sticking with 0.5.
global_grid_5 <- sf::st_make_grid(
  sf::st_as_sfc(bounding_box),
  cellsize = c(5, 5), #Increasing grid-cell size to 5 degrees in following May All-Team meeting
  crs = sf::st_crs(4326),
  what = "polygons"
)

# global_grid_1 <- sf::st_make_grid(sf::st_as_sfc(bounding_box),
#                                   cellsize = c(1, 1),
#                                   crs = sf::st_crs(4326),
#                                   what = "polygons")

grid_sf <- sf::st_sf(geometry = global_grid_5)

#Add grid ID:
grid_sf$grid_ID <- 1:nrow(grid_sf)


## Pull out location data:
diurn_on_loc <- diurn_on |>
  dplyr::select(station_id, latitude, longitude) |>
  dplyr::distinct() #4621 stations

diurn_ev_loc <- diurn_ev |>
  dplyr::select(station_id, latitude, longitude) |>
  dplyr::distinct() #4627 stations

noc_loc <- noc |>
  dplyr::select(station_id, latitude, longitude) |>
  dplyr::distinct() #2869 stations


#Create sf objects:
diurn_on_loc_sf <- diurn_on_loc |>
  sf::st_as_sf(coords = c('longitude', 'latitude'), crs = 4326)

diurn_ev_loc_sf <- diurn_ev_loc |>
  sf::st_as_sf(coords = c('longitude', 'latitude'), crs = 4326)

noc_loc_sf <- noc_loc |>
  sf::st_as_sf(coords = c('longitude', 'latitude'), crs = 4326)


#Determine which grid cell (grid_ID) each station (loc_ID) falls within:
diurn_on_grid <- sf::st_join(diurn_on_loc_sf, grid_sf, join = st_within) |>
  sf::st_drop_geometry() #A few more rows that diurn_loc are introduced here..

diurn_ev_grid <- sf::st_join(diurn_ev_loc_sf, grid_sf, join = st_within) |>
  sf::st_drop_geometry() #A few more rows that diurn_loc are introduced here..

noc_grid <- sf::st_join(noc_loc_sf, grid_sf, join = st_within) |>
  sf::st_drop_geometry() #A few more rows that diurn_loc are introduced here..

#Join information back to dataframe:
diurn_on_info <- diurn_on |>
  dplyr::left_join(diurn_on_grid)

diurn_ev_info <- diurn_ev |>
  dplyr::left_join(diurn_ev_grid)

noc_info <- noc |>
  dplyr::left_join(noc_grid)


### Create the random effect group (add a grouping variable for sp/site/week) to
### datasets, based on the grid_ID location.

## Diurnal onset:

#Create grouping variable:
diurn_on_final <- diurn_on_info[,
  sp_grid_wk := .GRP,
  .(species_id, grid_ID, week)
]


## Diurnal cessation:

#Create grouping variable:
diurn_ev_final <- diurn_ev_info[,
  sp_grid_wk := .GRP,
  .(species_id, grid_ID, week)
]


## Nocturnal:

#Nocturnal dataset needs a 'week' column. Add:
noc_final <- noc_info |>
  dplyr::mutate(week = lubridate::week(night_start))

#Create grouping variable:
noc_final[, sp_grid_wk := .GRP, .(species_id, grid_ID, week)]


### Check number of stations per grid cell, to see if we should adjust the grid
### cell size (want more than 1 station per cell, ideally).

noc_n_grid <- noc_final |>
  dplyr::select(grid_ID, station_id) |>
  dplyr::group_by(grid_ID) |>
  dplyr::summarise(num = n()) # all with more than 1

di_on_n_grid <- diurn_on_final |>
  dplyr::select(grid_ID, station_id) |>
  dplyr::group_by(grid_ID) |>
  dplyr::summarise(num = n()) # ~9 with only 1

diurn_ev_n_grid <- diurn_ev_final |>
  dplyr::select(grid_ID, station_id) |>
  dplyr::group_by(grid_ID) |>
  dplyr::summarise(num = n()) # ~8 with only 1


### Convert diurnal variables from minutes to hours for onset/cessation:

## Convert time variables from minutes to hours (only in diurnal):
diurn_on_final$first_onset <- (diurn_on_final$first_onset / 60)

diurn_ev_final$ev_ces <- (diurn_ev_final$ev_ces / 60)


### Save out final datasets, with all features and variables.

## Diurnal:
fwrite(
  diurn_on_final,
  here("data", "L3", "diurn_on_final.csv"),
  row.names = FALSE
)
fwrite(
  diurn_ev_final,
  here("data", "L3", "diurn_ev_final.csv"),
  row.names = FALSE
)


## Nocturnal:
fwrite(noc_final, here("data", "L3", "noc_final.csv"), row.names = FALSE)
