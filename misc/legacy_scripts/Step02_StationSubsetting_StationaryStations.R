#################################################################################
### Latitudinal Gradient / Macroecology / Clouds x Behavior 
### Step 02: Determine stationary stations.
### Overview: Take 'Raw Data' and subset based on inclusion criteria and data 
### subsetting needs. Do this prior to pairing weather data to Birdweather 
### stations. Outcome of this script is to determine those stations from the Raw
### Data files aggregated in the previous step (Step01) that are stationary. 
#################################################################################


#################################################################################
### STEP02 A: Logistics and getting started.
#################################################################################

## Clear workspace and clean up memory:
rm(list=ls())
gc(reset=TRUE)


## Load libraries:
library(tidyverse)
library(sf)
library(move2)
library(ggplot2)
library(janitor)
library(rnaturalearth)
library(rnaturalearthdata)


## Read in data:
d <- read.csv("Data/ProcessedData/all.stations.Feb.18.26.csv")


################################################################################
### Step02 B: Subset Step 1
################################################################################

### SUBSET STEP 1: Omit traveling stations.

## What this step does: There is often some imprecision or 'jitter' in some of 
## the Birdweather Station GPS coordinates meant to represent the location of 
## the recording unit. This imprecision can cause the same 'Stationary' recording
## station to have different coordinates associated with it. Not only does this 
## jitter exist, but some sations are not stattionary and instead represent mobile
## recoridng units (e.g. those taken in a backpack with a moving hiker). This step
## differentiates between stationary and mobile Stations, keeps only stationary 
## ones, and centralizes any jittered GPS coordinates into one coordinate per unique 
## station. Identify stationary versus mobile stations.


#Pull out a list of unique Station names:
station.names <- unique(d$Station) #2895 Stations


#Produce a function to loop around each Station name and assess it's GPS coordinates
#ultimately this function will determine if Station should be considered 'mobile' or 
#'stationary' (with jittered points) based on clustering of GPS points for each unique 
#Station. If stationary, one summarized point that is the average of the jittered points 
#will be spit out of the function as that Station's coordinate:
evaluate.points <- function(name){
  
  print(name)
  
  #Subset data to one Station:
  
  station.data <- d |>
    dplyr::select(Station, Latitude, Longitude) |>
    dplyr::filter(Station == name) |>
    dplyr::distinct()
  
  print(nrow(station.data))
  
  
  #Check to see if there is GPS jitter. If all GPS data is the same 
  #(which indicates a stationary station and does not require the 
  #buffering/averaging steps to come, stop here and print data:
  
  check <- nrow(station.data) 
  
  if(check==1){
    
    df.stationary <- station.data |>
      dplyr::mutate(class = "stationary",
                    station.LON = Longitude,
                    station.LAT = Latitude) |>
      dplyr::select(Station, station.LON, station.LAT) |>
      dplyr::distinct() 
    
    print("Station is stationary, with a single point")
    
  } else {
    
    print("Several points, function continues") 
    
    #If there is evidence of GPS jitter, continue with the following
    #procedure to (1) identify if stationary or mobile and (2) compute 
    #a single point from the median of the jittered data:
    
    #Convert to sf object:
    sf.points <- station.data |>
      sf::st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |>
      sf::st_transform(crs = 3857) #re-project to x, y for math calculations ahead
    
    #Create a buffer around each point (100m): 
    bufs <- sf::st_buffer(sf.points, dist = 100)
    
    #Determine which buffers overlap with each other / get intersection:
    overlap.list <- sf::st_intersects(bufs)
    
    #See how many overlaps each buffer has:
    overlap.counts <- sapply(overlap.list, length)
    
    #Calculate proportion of overlaps per buffer (subtracting 1 to remove self intersection):
    proportion.overlap <- (overlap.counts - 1) / (nrow(bufs) - 1)
    
    #Add results to sf object:
    b <- sf.points |> 
      dplyr::mutate(overlap.count = (overlap.counts - 1), 
                    overlap.prop = proportion.overlap,
                    Station = name) |>
      dplyr::mutate(flag = ifelse(overlap.prop > 0.8, 1, 0)) |>
      dplyr::group_by(Station) |>
      dplyr::summarise(prop.overlap = sum(flag) / sum(!is.na(flag))) |>
      sf::st_transform(crs = 4326)

    #Convert multipoint object into dataframe:
    df.points <- cbind(st_drop_geometry(b), st_coordinates(b))
    
    #Rename columns:
    df.points <- df.points |>
      dplyr::rename(Longitude = X,
                    Latitude = Y) |>
      dplyr::select(-L1)
    
    # #Transform bufs projection back to lat/lon, for visulaization:
    # bufs <- sf::st_transform(bufs, crs = 4326)
    # 
    # #Visualize:
    # g <- ggplot() +
    #   geom_point(data = df.points, 
    #              aes(Longitude, Latitude), 
    #              color="darkblue") +
    #   geom_sf(data = bufs, 
    #           aes(geometry = geometry), 
    #           color = "darkblue", 
    #           fill=NA, 
    #           alpha = 0.2) +
    #   labs(title = name) +
    #   theme_minimal() +
    #   theme(legend.position = "none")
    # 
    # print(g)
    
    #Define the condition / proportion of overlap we want to include:
    check <- df.points$prop.overlap >= 0.95 #NOTE: Can/might adjust what to set this as. 
    
    #Determine if all columns meet the condition defined above. If so, take the mean coordinate of 
    #all the "jittered" points as final GPS coordinate for the Station. If not, mark that station
    #as mobile and fill in station coords with NAs (eventually remove from analytical data).
    if(all(check)){
      
      #If true, designate Station as 'stationary' and calculate median coordinate as Station.ID and 
      #output the dataframe:
      df.stationary <- df.points %>%
        dplyr::mutate(class = "stationary",
                      station.LON = median(Longitude),
                      station.LAT = median(Latitude)) |>
        dplyr::select(Station, station.LON, station.LAT) |>
        dplyr::distinct()
      
      print("Station is stationary")
      
    } else {
      
      df.stationary <- c()
      
      print("Station is Mobile - Not Assessed")
      
    }
  }
  
  return(df.stationary)
}


#Check to see if function works on a subsets -- yes!:
Station2.check <- evaluate.points("22 Olivia") 
Station3.check <- evaluate.points("BirdNET-Pi - Arlington, NE")
Station4.check <- evaluate.points("Big Bear, CA") 
Station5.check <- evaluate.points("BirdNET Pi - Little Rock")


#Loop function around all Stations (using station.names list above) and output a 
#dataframe of stationary stations to evaluate further:
stations <- c()
 
for(name in station.names){
   all.stations <- evaluate.points(name)
   stations <- rbind(stations, all.stations)
}

#stations dataframe is the Station name and revised LAT, LON point associated with it.

stations <- janitor::clean_names(stations)

station.names.revisited <- unique(stations$station) #... Stations 

# #NOTE: re-look at some designations as a pulse check on the function. Make sure
# mobile stations seem mobile and stationary stations seem stationary. Also, can
# probably adjust ggplot map to make all point/buffer visualizations cleaner to
# look at and more standardized (though, might be hard with global data).

#Write out file, of stationary stations (the foundation for the rest of the subset):
write.csv(stations, "Data/ProcessedData/stationary.stations.LatCloud.Feb.18.26.csv", row.names = FALSE)


################################################################################
### Step02 C: Subset Step 1 - Re-done with Slight Variation (Quantile Range 
### Restriction) for Bird Cloud Project. Compare output dataframes. 
################################################################################

evaluate.points2 <- function(name){
  
  print(name)
  
  #Subset data to one Station:
  
  station.data <- d |>
    dplyr::select(Station, Latitude, Longitude) |>
    dplyr::filter(Station == name) |>
    dplyr::distinct()
  
  print(nrow(station.data))
  
  
  #Check to see if there is GPS jitter. If all GPS data is the same 
  #(which indicates a stationary station and does not require the 
  #buffering/averaging steps to come, stop here and print data:
  
  check <- nrow(station.data) 
  
  if(check==1){
    
    df.stationary <- station.data |>
      dplyr::mutate(class = "stationary",
                    station.LON = Longitude,
                    station.LAT = Latitude) |>
      dplyr::select(Station, station.LON, station.LAT) |>
      dplyr::distinct() 
    
    print("Station is stationary, with a single point")
    
    
  } else {
    
    print("Several points, function continues") 
    
    
    #First, plot points on a quantile range (x and y respectively) and eliminate
    #outliers:
    lat_Q1 <- quantile(station.data$Latitude, 0.25)
    lat_Q3 <- quantile(station.data$Latitude, 0.75)
    lat_IQR <- lat_Q3 - lat_Q1
    lat_lower_bound <- lat_Q1 - 1.5 * lat_IQR #Note: maybe change to 90th and 10th. Need to really understand what this equation is doing. 
    lat_upper_bound <- lat_Q3 + 1.5 * lat_IQR
    
    lon_Q1 <- quantile(station.data$Longitude, 0.25)
    lon_Q3 <- quantile(station.data$Longitude, 0.75)
    lon_IQR <- lon_Q3 - lon_Q1
    lon_lower_bound <- lon_Q1 - 1.5 * lon_IQR
    lon_upper_bound <- lon_Q3 + 1.5 * lon_IQR
    
    station.data.filtered <- station.data |>
      dplyr::filter(Latitude >= lat_lower_bound & Latitude <= lat_upper_bound 
                    & Longitude >= lon_lower_bound & Longitude <= lon_upper_bound)
    
    print(nrow(station.data.filtered))
    
    
    #If there is evidence of GPS jitter, continue with the following procedure 
    #on the filtered data (which removed outliers) to (1) identify if the station 
    #is stationary or mobile and (2) compute a single point from the median of the
    #jittered data:
    
    #Convert to sf object:
    sf.points <- station.data.filtered |>
      sf::st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |>
      sf::st_transform(crs = 3857) #re-project to x, y for math calculations ahead
    
    
    #Create a buffer around each point (100m): 
    bufs <- sf::st_buffer(sf.points, dist = 100)
    
    #Determine which buffers overlap with each other / get intersection:
    overlap.list <- sf::st_intersects(bufs)
    
    #See how many overlaps each buffer has:
    overlap.counts <- sapply(overlap.list, length)
    
    #Calculate proportion of overlaps per buffer (subtracting 1 to remove self intersection):
    proportion.overlap <- (overlap.counts - 1) / (nrow(bufs) - 1)
    
    #Add results to sf object:
    b <- sf.points |> 
      dplyr::mutate(overlap.count = (overlap.counts - 1), 
                    overlap.prop = proportion.overlap,
                    Station = name) |>
      dplyr::mutate(flag = ifelse(overlap.prop > 0.8, 1, 0)) |>
      dplyr::group_by(Station) |>
      dplyr::summarise(prop.overlap = sum(flag) / sum(!is.na(flag))) |>
      sf::st_transform(crs = 4326)
    
    #Convert multipoint object into dataframe:
    df.points <- cbind(st_drop_geometry(b), st_coordinates(b))
    
    #Rename columns:
    df.points <- df.points |>
      dplyr::rename(Longitude = X,
                    Latitude = Y) |>
      dplyr::select(-L1)
    
    # #Transform bufs projection back to lat/lon, for visulaization:
    # bufs <- sf::st_transform(bufs, crs = 4326)
    # 
    # #Visualize:
    # g <- ggplot() +
    #   geom_point(data = df.points, 
    #              aes(Longitude, Latitude), 
    #              color="darkblue") +
    #   geom_sf(data = bufs, 
    #           aes(geometry = geometry), 
    #           color = "darkblue", 
    #           fill=NA, 
    #           alpha = 0.2) +
    #   labs(title = name) +
    #   theme_minimal() +
    #   theme(legend.position = "none")
    # 
    # print(g)
    
    #Define the condition / proportion of overlap we want to include:
    check.again <- df.points$prop.overlap >= 0.95 #NOTE: Can/might adjust what to set this as. 
    
    #Determine if all columns meet the condition defined above. If so, take the mean coordinate of 
    #all the "jittered" points as final GPS coordinate for the Station. If not, mark that station
    #as mobile and fill in station coords with NAs (eventually remove from analytical data).
    if(all(check.again)){
      
      #If true, designate Station as 'stationary' and calculate median coordinate as Station.ID and 
      #output the dataframe:
      df.stationary <- df.points %>%
        dplyr::mutate(class = "stationary",
                      station.LON = median(Longitude),
                      station.LAT = median(Latitude)) |>
        dplyr::select(Station, station.LON, station.LAT) |>
        dplyr::distinct()
      
      print("Station is stationary")
      
    } else {
      
      df.stationary <- c()
      
      print("Station is Mobile - Not Assessed")
      
    }
  }
  
  return(df.stationary)
}

#Check to see if function works on a subsets:
Station2.check <- evaluate.points2("22 Olivia") 
Station3.check <- evaluate.points2("BirdNET-Pi - Arlington, NE")
Station4.check <- evaluate.points2("Big Bear, CA") 
Station5.check <- evaluate.points2("BirdNET Pi - Little Rock")


#Loop function around all Stations (using station.names list above) and output a 
#dataframe of stationary stations to evaluate further:
stations2 <- c()

for(name in station.names){
  all.stations <- evaluate.points2(name)
  stations2 <- rbind(stations2, all.stations)
}

#stations is the Station name and revised LAT, LON point associated with it.

stations2 <- janitor::clean_names(stations2)

station.names.revisited2 <- unique(stations2$station) # Stations

s <- stations2 |>
  dplyr::distinct() #Check only one lat/lon pulled for each station name. Yes!


#Write out file, of stationary stations (the foundation for the rest of the subset):
write.csv(stations2, "Data/ProcessedData/stationary.stations.BirdCloud.Feb.18.26.csv", row.names = FALSE)





