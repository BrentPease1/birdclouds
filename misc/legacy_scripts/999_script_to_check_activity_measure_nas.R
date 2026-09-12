library(here)
library(data.table)
library(stringr)
setDTthreads(0)

continents <- c("Africa",
                "Asia",
                "Europe",
                "North America",
                "Oceania",
                "South America")

base <- here('data/L0/activity_measures/diurnal')

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

months[, year := fcase(
  str_detect(name, "^\\d{4}"), as.integer(str_sub(name, 1, 4)),
  str_detect(name, "\\d{4}$"), as.integer(str_extract(name, "\\d{4}$")),
  str_detect(name, "\\d{2}$"), as.integer(paste0("20", str_extract(name, "\\d{2}$")))
)]

stash <- list()
stash_idx <- 1
total_rows_read <- 0L  
for (c in continents) {
  print(c)
  
  for (m in 1:nrow(months)) {
    this_month <- months[m, name]
    this_file <- list.files(
      path = base,
      pattern = paste0("activity_measures_", c, ".*", this_month, ".*\\.csv$"),
      full.names = T
    )
    
    if (length(this_file) == 0) {
      message(sprintf("  [%s | %s] SKIP — no file found", c, this_month))
      next
    }
    
    act <- fread(this_file)
    nrows_read <- nrow(act)
    total_rows_read <- total_rows_read + nrows_read
    # flag rows where value is NA
    questionable <- act[is.na(value), ]
    
    if (nrow(questionable) == 0) {
      message(sprintf("  [%s | %s] OK — %d rows read, 0 NA values", c, this_month, nrows_read))
      next
    } else {
      questionable[, `:=`(continent = c, month = this_month)]
      stash[[stash_idx]] <- questionable
      stash_idx <- stash_idx + 1
      message(sprintf("  [%s | %s] FLAG — %d rows read, %d NA values", c, this_month, nrows_read, nrow(questionable)))
    }
  } # months
} # continents

message(sprintf("Total rows read across all files: %d", total_rows_read))
questionable_all <- rbindlist(stash)

fwrite(questionable_all, here('data/L0/activity_measures/questionable_na.csv'))