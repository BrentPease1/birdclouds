library(here)
library(data.table)
library(lubridate)
library(suncalc)
library(lutz)
library(sf)
library(activity)
library(stringr)
setDTthreads(0)

confidence_cutoff <- c(0.75)
detection_filter <- c(20)
continents <- c("Africa",
                "Asia",
                "Europe",
                "North America",
                "Oceania",
                "South America")

# file base name
base <- here('data/L0/activity_measures/diurnal')

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
months[, year := fcase(
  str_detect(name, "^\\d{4}"), as.integer(str_sub(name, 1, 4)),
  str_detect(name, "\\d{4}$"), as.integer(str_extract(name, "\\d{4}$")),
  str_detect(name, "\\d{2}$"), as.integer(paste0("20", str_extract(name, "\\d{2}$")))
)]


# debugging helpers
# c = 'Africa'
# m = 1

# initialize stash before the loops
stash <- list()
stash_idx <- 1

for (c in continents) {
  print(c)
  
  for (m in 1:nrow(months)) {
    # focal month for setting up period variable
    this_month <- months[m, name]
    # this_file to be read in
    this_file <- list.files(
      path = base,
      pattern = paste0("activity_measures_", c, ".*", this_month, ".*\\.csv$") ,
      full.names = T
    )
    
    if (length(this_file) == 0) {
      message(sprintf("  [%s | %s] SKIP — no file found", c, this_month))
      next
    }
    
    # load in activity measure
    act <- fread(this_file)
    nrows_read <- nrow(act)
    
    # find values outside of 8 hrs
    questionable <- act[abs(value) > 600, ]
    
    if (nrow(questionable) == 0) {
      message(sprintf("  [%s | %s] OK — %d rows read, 0 questionable", c, this_month, nrows_read))
      next
    } else {
      questionable[, `:=`(continent = c, month = this_month)]
      stash[[stash_idx]] <- questionable
      stash_idx <- stash_idx + 1
      message(sprintf("  [%s | %s] FLAG — %d rows read, %d questionable", c, this_month, nrows_read, nrow(questionable)))
    }
  } # months
} #continents

# combine all questionable rows into one table
questionable_all <- rbindlist(stash)

# plot it to see where things are happening
library(sf) 
t <- questionable_all
t <- st_as_sf(t, coords = c('longitude', 'latitude'), crs = 4326)
library(mapview)
mapview(t)

fwrite(questionable_all, here('data/L0/activity_measures/questionable.csv'))