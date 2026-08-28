#Lines 1-350 from 301_DataAnalysis_Processing.R
# I added lines to improve reading & saving data with .rds files

################################################################################
### Gilbert X Pease - Bird Cloud Project
### Processing Data for Analysis
### First analytical step, pre-modeling of diurnal and nocturnal species
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
here::i_am("scripts/L3/301_join_elton_traits.R")


### Read in Data:

#Trait data (will grab Family, activity period):
elton <- traitdata::elton_birds


load(here("data", "L2", "final_nocturnal.RData"))
load(here("data", "L2", "final_diurnal_first_onset.RData"))
load(here("data", "L2", "final_diurnal_ev_ces.RData"))

# #Analysis data (from data prep-pull team):
# load("D:/BirdCloudProject/Data/Final/final_nocturnal.RData")
# load("D:/BirdCloudProject/Data/Final/final_diurnal_first_onset.RData")
# load("D:/BirdCloudProject/Data/Final/final_diurnal_ev_ces.RData")

### Add some BirdWeather data back to datasets (nocturnal: sci_name and sp_id;
### diurnal: sp_id).

#Determine names to loop over:
noc_com <- unique(final_nocturnal$common_name)

c <- final_nocturnal |>
  dplyr::select(common_name) |>
  dplyr::distinct()

#Loop through list of names and grab BirdWeather info:
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

#Loop through list of names and grab BirdWeather info:
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
matched <- sp_traits |> dplyr::filter(!is.na(nocturnal))
unmatched <- sp_traits |> dplyr::filter(is.na(nocturnal))

# Step 2: try to recover unmatched using common name
recovered <- unmatched |>
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
sp_traits_final <- dplyr::bind_rows(matched, recovered)

# Step 4: assign activity period, write out sp_traits_final
sp_traits_final <- sp_traits_final |>
  dplyr::mutate(
    activity_period = ifelse(nocturnal == 0, "diurnal", "nocturnal")
  )

# Step 5: check what's still missing
#Scientific names from Birds of the World, researcher knowledge
to_assess <- sum(is.na(sp_traits_final$activity_period)) # now 16 missing --> manually fill


## Manually fill in 16 missing joins - to generate "missing_final" dataframe.

# Pull out a dataframe of the missing joins:
to_assess <- sp_traits_final |>
  dplyr::filter(is.na(activity_period))

###Save out and manually fill in:
# fwrite(
#   to_assess,
#   "Data/Final/to_assess_manually_May2026.csv",
#   row.names = FALSE
# )

fwrite(
  to_assess,
  here("data", "L3", "301_elton_traits", "to_assess_manually_May2026.csv"),
  row.names = FALSE
)

## read back in filled out missing, re-join with sp_traits and get one final df
#missing_filled <- read.csv("Data/Final/missing_final.csv")
missing_filled <- read.csv(here(
  "data",
  "L3",
  "301_elton_traits",
  "missing_final.csv"
))


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
sp_traits_no_missing <- sp_traits_clean |>
  na.omit()

#add back in (now filled in)
final_traits <- dplyr::bind_rows(sp_traits_no_missing, missing_clean)

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

# # Read out the data:
# fwrite(noc_data, "Data/Final/noc_data.csv", row.names = FALSE)
# fwrite(diurn_on_data, "Data/Final/diurn_on_data.csv", row.names = FALSE)
# fwrite(diurn_ev_data, "Data/Final/diurn_ev_data.csv", row.names = FALSE)

saveRDS(
  diurn_on_data,
  file = here("data", "L3", "301_elton_traits", "301a_diurn_on_data.rds")
)
saveRDS(
  diurn_ev_data,
  file = here("data", "L3", "301_elton_traits", "301b_diurn_ev_data.rds")
)
saveRDS(
  noc_data,
  file = here("data", "L3", "301_elton_traits", "301c_noc_data.rds")
)
