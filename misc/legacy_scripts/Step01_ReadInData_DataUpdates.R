#################################################################################
### Latitudinal Gradient / Macroecology / Clouds x Behavior 
### Step 01: Read in data.
### Overview: Read in global Birdweather data, with the aim of grabbing station-
### level variables.
#################################################################################


#################################################################################
### STEP01 A: Logistics and getting started.
#################################################################################

## Clear workspace and clean up memory:
rm(list=ls())
gc(reset=TRUE)

options(timeout = 1000)


## Load libraries:
library(here)
library(data.table)
library(lubridate)
library(suncalc)
library(lutz)
library(sf)
library(activity)
library(stringr)
library(spData)
setDTthreads(0)


#################################################################################
### STEP01 B: Read in All Station Data 
#################################################################################

## Set broad file path containing all Raw Data:
base1 <- "Data/RawData/Birdweather"
base2 <- "Data/RawData/BirdweatherAdditional"
bases <- c(base1, base2)


## Create vector of continents to loop data around:
continents <- c("Africa", "Asia", "Europe", "North America", "Oceania", "South America")


## Pull in continent shapefile for filtering lat / lon below:
#continent_shapes <- spData::world


## Create emplty lists to fill with data as it's read in: 
results_list <- list(list())

results_list_continent <- list(list())

results_list_bases <- list(list())


## Loop to read in Raw Data from Birdweather:
for(b in bases) {
  
  if(b == base1) {
    
    for(c in continents) {
      
      print(c)
      
      if(c == "North America" | c == "South America") {
        
        months <- data.frame(name = c("mar2023", "apr2023", "may2023", "jun2023", 
                                      "jul2023", "aug2023", "sept2023", "oct2023", 
                                      "nov2023", "dec2023", "jan2024", "feb2024", 
                                      "mar2024"))
      } else {
        
        months <- data.frame(name = c("mar23", "apr23", "may23", "jun23", "jul23", 
                                      "aug23", "sept23", "oct23", "nov23", "dec23", 
                                      "jan24", "feb24", "mar24"))
      }
      
      # months <- months %>%
      #   dplyr::mutate(year = dplyr::case_when(str_detect(name, "^\\d{4}") ~
      #                                           as.integer(str_sub(name, 1, 4)),
      #                                         str_detect(name, "\\d{4}$") ~
      #                                           as.integer(str_extract(name, "\\d{4}$")),
      #                                         str_detect(name, "\\d{2}$") ~
      #                                           as.integer(paste0("20", str_extract(name, "\\d{2}$")))))

      for(m in 1:nrow(months)) {
        
        # focal month for setting up period variable
        this_month <- months[m, ]
        
        this_file <- list.files(path = paste0(b, "/", c), 
                                pattern = paste0(".*", this_month, "\\.csv$"),
                                full.names = T)
        
        # some data files might not exist
        # because they haven't been downloaded yet
        if(rlang::is_empty(this_file)){
          
          cat('\n\n', c, this_month, "doesn't exist\n\n")
          
          next
        }
        
        # load in Birdweather
        bw <- fread(this_file)
    
        # deal with different column names in each file
        if(c == "Europe" & m == 1) {
          
          setnames(bw, old = c("confidence",
                                "species.commonName",
                                "species.scientificName",
                                "coords.lat",
                                "coords.lon",
                                "station.name",
                                "timestamp"), 
                   new = c("Confidence", 
                           "Common Name", 
                           "Scientific Name",
                           "Latitude", 
                           "Longitude", 
                           "Station",
                           "Timestamp")) 
        }
        
        # drop unnecessary columns
        # pull out just date and then take unique dates not TIMES.
        bw <- bw |> 
          dplyr::select(Station, Latitude, Longitude, Timestamp) |> 
          dplyr::mutate(date = lubridate::as_date(Timestamp),
                        year = lubridate::year(date)) |>
          dplyr::group_by(Station) |>
          dplyr::mutate(ndays = length(unique(date))) |>
          dplyr::select(Station, Latitude, Longitude, ndays, date, year) |>
          dplyr::mutate(continent = c) |>
          dplyr::distinct()
        
        # filter down to continent
        # get rid of obs outside of focal continent
        # bw$index <- 1:nrow(bw)
        # tmp <- bw
        # tmp <- st_as_sf(tmp, coords = c("Longitude", "Latitude"), crs = 4326)
        # t <- sapply(st_intersects(tmp, continent_shapes |>
        #                             dplyr::filter(continent == c)), function(z) if (length(z)==0) NA_integer_ else z[1])
        # tmp <- tmp[!is.na(t),]; rm(t) # throws out data
        # bw <- bw[bw$index %in% tmp$index,] #filter bw down to good index values
        # rm(tmp)
        # 
        # dump into holder:
        results_list[[m]] <- bw 
        
      } #months
      
      results_list_continent[[which(continents == c) ]] <- do.call(rbind, results_list) 
    }
    
  } else {
    
    for(c in continents) {
        
        print(c)
        
        months <- data.frame(name = c("2024_04","2024_05","2024_06","2024_07",
                                      "2024_08","2024_09","2024_10",
                                      "2024_11","2024_12","2025_01",
                                      "2025_02","2025_03","2025_04",
                                      "2025_05","2025_06"))
        
        # months <- months %>%
        #   dplyr::mutate(
        #     year = dplyr::case_when(
        #       str_detect(name, "^\\d{4}") ~ as.integer(str_sub(name, 1, 4)),
        #       str_detect(name, "\\d{4}$") ~ as.integer(str_extract(name, "\\d{4}$")),
        #       str_detect(name, "\\d{2}$") ~ as.integer(paste0("20", str_extract(name, "\\d{2}$")))
        #     )
        #   )
        
        for(m in 1:nrow(months)) {
          
          # focal month for setting up period variable
          this_month <- months[m, ]
          
          this_file <- list.files(path = paste0(b, "/", c), 
                                  pattern = paste0(gsub(" ", "_", c), "_detections_", ".*", this_month, "\\.csv$"),
                                  full.names = T)
          
          # some data files might not exist
          # because they haven't been downloaded yet
          if(rlang::is_empty(this_file)){
            
            cat('\n\n', c, this_month, "doesn't exist\n\n")
            
            next
          }
          
          # load in Birdweather
          bw <- fread(this_file)
          
          # deal with different column names in each file
          setnames(bw, old = c("timestamp",
                               "station_name",
                               "latitude",
                               "longitude",
                               "station_type"), 
                   new = c("Timestamp",
                           "Station",
                           "Latitude", 
                           "Longitude",
                           "StationType"))
          
          # drop unnecessary columns
          # pull out just date and then take unique dates not TIMES.
          bw <- bw |> 
            dplyr::select(Station, Latitude, Longitude, Timestamp, StationType) |> 
            dplyr::mutate(date = lubridate::as_date(Timestamp),
                          year = lubridate::year(date)) |>
            dplyr::group_by(Station) |>
            dplyr::mutate(ndays = length(unique(date))) |>
            dplyr::select(Station, StationType, Latitude, Longitude, ndays, date, year) |>
            dplyr::mutate(continent = c) |>
            dplyr::distinct()
          
          # filter down to continent
          # bw$index <- 1:nrow(bw)
          # tmp <- bw
          # tmp <- st_as_sf(tmp, coords = c("Longitude", "Latitude"), crs = 4326)
          # t <- sapply(st_intersects(tmp, continent_shapes |>
          #                             dplyr::filter(continent == c)), function(z) if (length(z)==0) NA_integer_ else z[1])
          # tmp <- tmp[!is.na(t),]; rm(t)
          # bw <- bw[bw$index %in% tmp$index,]
          # rm(tmp)
          
          # dump into holder
          results_list[[m]] <- bw
          
        } #months
        
        results_list_continent[[which(continents == c)]] <- do.call(rbind, results_list) 
        
        } #continents
    
    } #else bases
  
  results_list_bases[[which(bases == b)]] <- do.call(rbind, results_list_continent)
  
}

  
## Convert list of lists into a dataframe:
## OUTPUT: All global records of unique combos of station/lat/lon
df.stations <- do.call(rbind, results_list_bases) 

stations <- df.stations |>
  dplyr::select(Station, StationType, Latitude, Longitude) |>
  dplyr::distinct()


## Write out file:
write.csv(stations, "Data/ProcessedData/all.stations.Feb.18.26.csv", row.names=FALSE)


#################################################################################
### STEP01 B: Read in All BirdWeather Observation Data of Vocalizations
#################################################################################

## Create empty lists to fill with data as it's read in: 
results_list.obs <- list(list())

results_list_continent.obs <- list(list())

results_list_bases.obs <- list(list())


## Loop to read in Raw Data from Birdweather:
for(b in bases) {
  
  if(b == base1) {
    
    for(c in continents) {
      
      print(c)
      
      if(c == "North America" | c == "South America") {
        
        months <- data.frame(name = c("mar2023", "apr2023", "may2023", "jun2023", 
                                      "jul2023", "aug2023", "sept2023", "oct2023", 
                                      "nov2023", "dec2023", "jan2024", "feb2024", 
                                      "mar2024"))
      } else {
        
        months <- data.frame(name = c("mar23", "apr23", "may23", "jun23", "jul23", 
                                      "aug23", "sept23", "oct23", "nov23", "dec23", 
                                      "jan24", "feb24", "mar24"))
      }
      
      for(m in 1:nrow(months)) {
        
        # focal month for setting up period variable
        this_month <- months[m, ]
        
        this_file <- list.files(path = paste0(b, "/", c), 
                                pattern = paste0(".*", this_month, "\\.csv$"),
                                full.names = T)
        
        # some data files might not exist
        # because they haven't been downloaded yet
        if(rlang::is_empty(this_file)){
          
          cat('\n\n', c, this_month, "doesn't exist\n\n")
          
          next
        }
        
        # load in Birdweather
        bw <- fread(this_file)
        
        # deal with different column names in each file
        if(c == "Europe" & m == 1) {
          
          setnames(bw, old = c("confidence",
                               "species.commonName",
                               "species.scientificName",
                               "station.name",
                               "timestamp"), 
                   new = c("Confidence", 
                           "Common Name", 
                           "Scientific Name",
                           "Station",
                           "Timestamp")) 
        }
        
        # drop unnecessary columns
        # pull out all BirdWeather observations from all stations.
        # note that we are not reading out lat and lon variables because
        # step 02 will assign these.
        bw <- bw |> 
          dplyr::select("Confidence", 
                        "Common Name", 
                        "Scientific Name",
                        "Station",
                        "Timestamp") |>
          janitor::clean_names() 
   
        # dump into holder:
        results_list.obs[[m]] <- bw 
        
      } #months
      
      results_list_continent.obs[[which(continents == c) ]] <- do.call(rbind, results_list.obs) 
    }
    
  } else {
    
    for(c in continents) {
      
      print(c)
      
      months <- data.frame(name = c("2024_04","2024_05","2024_06","2024_07",
                                    "2024_08","2024_09","2024_10",
                                    "2024_11","2024_12","2025_01",
                                    "2025_02","2025_03","2025_04",
                                    "2025_05","2025_06"))
      
      for(m in 1:nrow(months)) {
        
        # focal month for setting up period variable
        this_month <- months[m, ]
        
        this_file <- list.files(path = paste0(b, "/", c), 
                                pattern = paste0(gsub(" ", "_", c), "_detections_", ".*", this_month, "\\.csv$"),
                                full.names = T)
        
        # some data files might not exist
        # because they haven't been downloaded yet
        if(rlang::is_empty(this_file)){
          
          cat('\n\n', c, this_month, "doesn't exist\n\n")
          
          next
        }
        
        # load in Birdweather
        bw <- fread(this_file)
        
        # deal with different column names in each file
        setnames(bw, old = c("timestamp",
                             "station_name",
                             "scientific_name",
                             "common_name",
                             "confidence"), 
                 new = c("Timestamp",
                         "Station",
                         "Scientific Name",
                         "Common Name",
                         "Confidence"))
        
        # drop unnecessary columns
        # pull out all BirdWeather observations from all stations.
        # note that we are not reading out lat and lon variables because
        # step 02 will assign these.
        bw <- bw |> 
          dplyr::select("Confidence", 
                        "Common Name", 
                        "Scientific Name",
                        "Station",
                        "Timestamp") |>
          janitor::clean_names() 
        
        # dump into holder
        results_list.obs[[m]] <- bw
        
      } #months
      
      results_list_continent.obs[[which(continents == c)]] <- do.call(rbind, results_list.obs) 
      
    } #continents
    
  } #else bases
  
  results_list_bases.obs[[which(bases == b)]] <- do.call(rbind, results_list_continent.obs)
  
}


## Convert list of lists into a dataframe:
## OUTPUT: All Birdweather vocal detections.
df.obs <- do.call(rbind, results_list_bases.obs)

## Write out file:
write.csv(df.obs, "Data/ProcessedData/all.observations.Feb.18.26.csv", row.names=FALSE)





