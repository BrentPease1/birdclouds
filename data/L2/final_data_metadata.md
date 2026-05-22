
# final_data_metadata.md

This file describes the data contained in the final data files prepared
for modelling and analyses, including [**final_diurnal.RData**](#final_diurnalrdata) and
[**final_nocturnal.RData**](#final_nocturnalrdata). Note that the exact same datasets are also
provided with different extensions: `.csv` or `.rds`

**Table of Contents**
- [final\_data\_metadata.md](#final_data_metadatamd)
  - [Covariate Info](#covariate-info)
    - [VIIRS Data](#viirs-data)
    - [Weather Data](#weather-data)
    - [Moonlight Data](#moonlight-data)
    - [Elevation Data](#elevation-data)
  - [Datasets](#datasets)
    - [**final\_diurnal.RData**](#final_diurnalrdata)
    - [**final\_nocturnal.RData**](#final_nocturnalrdata)

## Covariate Info

### VIIRS Data

VIIRS =  Visible and Infrared Imaging Suite

As in the [ALAN paper](https://github.com/BrentPease1/alan), we used
"monthly cloud-free VIIRS Day Night Band (DNB) data publicly available
for download from the [Earth Observation Group](https://eogdata.mines.edu/products/vnl/)."

We downloaded every tile available from April 2024 - April 2025 from the
Earth Observation Group. 
Example path to files: Home > nighttime_light > monthly > v10 > 2023 > 202301 > vcmslcfg

From this data, we got one variable: `avg_rad`

* `avg_rad` value has the following units: (avg_rade9h) nW/cm^2/sr
* VIIRS data has a resolution of: 15 arc second (~500m at the Equator)

We also categorized `avg_rad` into a column called `rad_cat`.

The `quantile()` function (see below) split the `avg_rad` values into three
equal-sized groups based on the data distribution, where "low" refers to
`avg_rad` values in the lower third of the distribution 
(lowest radiance = darkest skies), "med" refers to `avg_rad` values in the
middle, and "high" refers to `avg_rad` values in the upper third of the
distribution (highest radiance = brightest skies).

```r
# --- pulled from the VIIRS script
# categorize nighttime light
out[, rad_cat := fcase(
  avg_rad < quantile(avg_rad, probs = 0.334, na.rm = T), "low",
  avg_rad >= quantile(avg_rad, probs = 0.334, na.rm = T) & avg_rad < quantile(avg_rad, probs = 0.667, na.rm = T), "med",
  avg_rad >= quantile(avg_rad, probs = 0.667, na.rm = T), "high"
)]
```


### Weather Data

Weather was extracted from the [open-meteo API](https://open-meteo.com/)

**Open-Meteo** is an open-source weather API with high spatiotemporal resolution

Specifically, we fetched **open-meteo** data from the
[Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api)
We did NOT fetch from the [Historical *Forecast* API](https://open-meteo.com/en/docs/historical-forecast-api)
because the latter is a weather forecast (i.e., prediction), and the former is
the corrected version of the forecast with data assimilation from what actually
occurred

We also only pulled weather data from the **ECMWF_IFS weather model**. 
While there are many models with differing resolutions, we chose this ECMWF_IFS
because it (1) has global coverage, (2) relatively high spatial resolution at 9km,
(3) high temporal resolution at 1-hr intervals, and (4) the data is available
during our study period.

> We could have automatically pulled from multiple models to get the best spatial
resolution available, but we decided to not do this in order to avoid data
discrepancies as a result of different model algorithms and resolutions

Seven measures of weather data were pulled from **open-meteo**.
As a result, both the diurnal and nocturnal datasets contain at least 7

Weather variable name | description* | unit | resolution
|---|---|---|---|       
`cloud_cover_percent` | Total cloud cover as an area fraction | % | 9km
`cloud_cover_low_percent` | Low level clouds and fog up to 2 km altitude | % | 9km
`cloud_cover_mid_percent` | Mid level clouds from 2 to 6 km altitude | % | 9km
`cloud_cover_high_percent` | High level clouds from 6 km altitude | % | 9km
`precipitation_mm` | Total precipitation (rain, showers, snow) sum of the preceding hour. Data is stored with a 0.1 mm precision. If precipitation data is summed up to monthly sums, there might be small inconsistencies with the total precipitation amount. | mm | 9km
`rain_mm`  | Only liquid precipitation of the preceding hour including local showers and rain from large scale systems. | mm | 9km
`snowfall_cm` | Snowfall amount of the preceding hour in centimeters. For the water equivalent in millimeter, divide by 7. E.g. 7 cm snow = 10 mm precipitation water equivalent | cm | 9km

*note that descriptions are copied from the
[open-meteo API docs](https://open-meteo.com/en/docs/historical-weather-api)
for your convenience.

### Moonlight Data

Moonlight intensity data was calculated using the MoonShineR package
([paper](https://besjournals.onlinelibrary.wiley.com/doi/full/10.1111/2041-210X.14299);
[GitHub repo](https://github.com/Crampton-Lab/MoonShine);
[package info](https://lokpoon.github.io/MoonShine_manual/lux_calculator.html))

The moonlight data was calculated using the `MoonShineR::predict_lux()` function.
We calculated hourly data for each BirdWeather station, given its lat/lon coords 
and site elevation ([see elevation for more info](#elevation-data)). Specifically,
**for the moonlight data value, we calculated `moon_final_lux_nighttime`.**

According to MoonShineR, `moon_final_lux_nighttime` is:

> Only the illuminance of moonlight at night (no value during daytime, when
`sun_altitude` > 0 degrees)

Essentially, this value does not include the illuminance of sunlight. It removes
the hours where the sun's position relative to the elevation of the station
still had an effect on illumination. Thus, it only keeps the hours where the
moon is 'active'.

The moonlight data was summarized for each `station_id` and `night_id`
using `night_start` and `night_end`. 

We delineated nights with:

* `night_id` = the day of the month (e.g., a date of 2026-05-08 will have
`night_id` of 8)
* `night_start` = the UTC sunset of the day of `night_id`
* `night_end` = the UTC sunrise following the sunset of `night_start`

We summarized moonlight data using the following summary statistics:

* mean moonlight between `night_start` and `night_end`
* median moonlight between `night_start` and `night_end`
* max moonlight between `night_start` and `night_end`
* min moonlight between `night_start` and `night_end`
* Moonlight at approximately "solar midnight"
  * The hourly data for moonlight (using MoonShineR's
  `moon_final_lux_nighttime`) may not have a value for every hour between
  `night_start` and `night_end` because MoonShineR did not yet consider that
  hour as "nighttime" (see description of `moon_final_lux_nighttime` above).
  * Thus, "solar midnight" refers to the closest maximum value to the midpoint
  (in hours) between `night_start` and `night_end`
  * For example:
    * `night_start` occurs on Friday at 8 pm (e.g., UTC 2025-05-18 20:00:00)
    * `night_end` occurs on Saturday at 6 am (e.g., UTC 2025-05-19 05:00:00)
    * The midpoint of the night occurs on Saturday at 12:30 am
    (e.g., UTC 2025-05-19 00:30:00)
    * The closest value in the raw hourly data will be at either 12am or 1am.
    * Thus, we take the value that is higher (i.e., the max). 
    * This avoids issues where the midpoint occurs very closely to what
    MoonShineR considers the "start" of "nighttime", such that if one is
    missing, then we just take the closest value.
  

### Elevation Data

To calculate moonlight data, we also pulled elevation data from the lat/lon
coords of each `station_id`.

The package `elevatr` was used to get the elevation of each station using
the lat/lon coords of the station. Using `elevatr::get_elev_point()`, we
pulled elevation data from an API. Specifically, we pulled elevation data with
the argument `src = "aws`, which downloads a DEM and extracts elevation for
each lat/lon coord from the [Amazon Web Services Terrain Tiles](https://registry.opendata.aws/terrain-tiles/).
Elevation data is returned in meters.


## Datasets

### **final_diurnal.RData**

*Updated version 04/27/2026* Rather than having one big dataset with all the values for `first_onset` and `ev_ces`, we split the diurnal dataset into two datasets. Both datasets contain nearly all the same columns described below, with the exception that one dataset only has the `first_onset` column and the other only has the `ev_ces` column to differentiate data used for modelling. The `final_diurnal` dataset still exists, with `first_onset`, `ev_ces`, and `median_dawn` contained in a long-format in the columns `category` and `value`. 

* [**final_diurnal_first_onset.RData**](https://saluki.sharepoint.com/:u:/r/sites/Test_rxb5sl/Shared%20Documents/General/data_prep_pull/ANALYSIS_READY_DATA/final_diurnal_first_onset.RData?csf=1&web=1&e=fxFph4) - diurnal dataset for `first_onset` vocalizations
* [**final_diurnal_ev_ces.RData**](https://saluki.sharepoint.com/:u:/r/sites/Test_rxb5sl/Shared%20Documents/General/data_prep_pull/ANALYSIS_READY_DATA/final_diurnal_ev_ces.RData?csf=1&web=1&e=69RKEg) - diurnal dataset for `ev_ces` (evening cessation) vocalizations

The diurnal datasets can be downloaded from the shared TEAMS folder:
[`General/data_prep_pull/ANALYSIS_READY_DATA/...`](https://saluki.sharepoint.com/:f:/r/sites/Test_rxb5sl/Shared%20Documents/General/data_prep_pull/ANALYSIS_READY_DATA?csf=1&web=1&e=e0JODb)


[**final_diurnal.RData**](https://saluki.sharepoint.com/:u:/r/sites/Test_rxb5sl/Shared%20Documents/General/data_prep_pull/ANALYSIS_READY_DATA/final_diurnal.RData?csf=1&web=1&e=V7p4qz)
is the final dataset used for diurnal modelling analyses. The dataset contains 30 columns. This dataset includes `first_onset`, `ev_ces`, and `median_dawn` contained in a long-format in the columns `category` and `value`, rather than each metric having its own column as in **final_diurnal_first_onset.RData** and **final_diurnal_ev_ces.RData**


Load the data into R with the dataframe object named as `final_diurnal`
```r
your_directory <- "specify_file_path"
load(here(your_directory, "final_diurnal_first_onset.RData")) # Just first_onset data
load(here(your_directory, "final_diurnal_ev_ces.RData")) # Just ev_ces data
load(here(your_directory, "final_diurnal.RData")) # first_onset, median_dawn, and ev_ces data
```

The names, descriptions, and data classes of each column are described below:

Column number | Column name | Description of column | Data class of column
|---|---|---|---|
[1] | `common_name` | common name of vocalizing species | (string)
[2] | `scientific_name` | scientific name of vocalizing species | (string)
[3] | `date_time` | date and time of vocalization in UTC timezone | (POSIXct)
[4] | `date` | date of vocalization | (Date)
[5] | `week` | calendar week of the year the vocalization occurred | (double)
[6] | `latitude` | latitude coordinate of the station where vocalization was recorded | (double)
[7] | `longitude` | longitude coordinate of the station where vocalization was recorded | (double)
[8] | `station_id` | unique identifier for the BirdWeather station of the recorded vocalization | (double)
[9] | `year` | year of vocalization; extracted from [4] `date` | (double)
[10] | `month` | month of vocalization; extracted from [4] `date` | (integer)
[11] | `avg_rad` | average radiance; unit = nW/cm^2/sr ([see VIIRS for more info)](#viirs-data)) | (double)
[12] | `rad_cat` | category of radiance, classified has "low", "med", or "high" ([see VIIRS for more info](#viirs-data)) | (string)
[13 - `first_onset` dataset] | `first_onset` | [time of first vocalization detection minus time of local sunrise] (time unit is in minutes) | (double)
[X - only in `final_diurnal` dataset] | `median_dawn` | [time of 50% vocalization detection minus time of local sunrise] (time unit is in minutes) | (double)
[13 - `ev_ces` dataset] | `ev_ces` | [time of last detection minus time of local sunset] (time unit is in minutes) | (double) 
[14] | `sunrise` | date and time of sunrise on the [3] `date_time` of the vocalization in UTC timezone | (POSIXct)
[15] | `sunset` | date and time of sunset on the [3] `date_time` of the vocalization in UTC timezone | (POSIXct)
[16] | `sunrise_cloud_cover_percent` | mean [cloud_cover (unit = %)](#weather-data) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[17] | `sunrise_cloud_cover_low_percent` | mean [cloud_cover_low (unit = %)](#weather-data) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[18] | `sunrise_cloud_cover_mid_percent` | mean [cloud_cover_mid (unit = %)](#weather-data) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[19] | `sunrise_cloud_cover_high_percent` | mean [cloud_cover_high (unit = %)](#weather-data) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[20] | `sunrise_precipitation_mm` | mean [precipitation (unit = millimeters)](#weather-data) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[21] | `sunrise_rain_mm` | mean [rain (unit = millimeters)](#weather-data) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[22] | `sunrise_snowfall_cm` | mean [snowfall (unit = millimeters)](#weather-data) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[23] | `sunset_cloud_cover_percent` | mean [cloud_cover (unit = %)](#weather-data) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[24] | `sunset_cloud_cover_low_percent` | mean [cloud_cover_low (unit = %)](#weather-data) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[25] | `sunset_cloud_cover_mid_percent` | mean [cloud_cover_mid (unit = %)](#weather-data) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[26] | `sunset_cloud_cover_high_percent` | mean [cloud_cover_high (unit = %)](#weather-data) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[27] | `sunset_precipitation_mm` | mean [precipitation (unit = millimeters)](#weather-data) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[28] | `sunset_rain_mm` | mean [rain (unit = millimeters)](#weather-data) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[29] | `sunset_snowfall_cm` | mean [snowfall (unit = millimeters)](#weather-data) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)


### **final_nocturnal.RData**

[**final_nocturnal.RData**](https://saluki.sharepoint.com/:f:/r/sites/Test_rxb5sl/Shared%20Documents/General/data_prep_pull/ANALYSIS_READY_DATA?csf=1&web=1&e=RMAs1a)
is the final dataset used for nocturnal modelling analyses. The dataset contains 24 columns.

The nocturnal dataset can be downloaded from the shared TEAMS folder:
[`General/data_prep_pull/ANALYSIS_READY_DATA/final_diurnal.RData`](https://saluki.sharepoint.com/:f:/r/sites/Test_rxb5sl/Shared%20Documents/General/data_prep_pull/ANALYSIS_READY_DATA?csf=1&web=1&e=RMAs1a)

Load the data into R with the dataframe object named as `final_nocturnal`
```r
your_directory <- "specify_file_path"
load(here(your_directory, "final_nocturnal.RData"))
```

The names, descriptions, and data classes of each column are described below:

Column number | Column name | Description of column | Data class of column
|---|---|---|---|
[1] | "station_id" | unique identifier for the BirdWeather station of the recorded vocalization | (double)
[2] | "night_id" | the day of the month (e.g., a date of 2026-05-08 will have `night_id` of 8) | (double)
[3] | "night_start" | the UTC sunset of the day of `night_id` | (POSIXct)
[4] | "night_end" | the UTC sunrise following the sunset of `night_start` | (POSIXct)
[5] | "year" | year of vocalization; extracted from [3] `night_start` | (double)
[6] | "month" | month of vocalization; extracted from [3] `night_start` | (integer)
[7] | "common_name" | common name of vocalizing species | (string)
[8] | "det" | **???? Presence/absence of vocalization?** | (double)
[9] | "latitude" | latitude coordinate of the station where vocalization was recorded | (double)
[10] | "longitude" | longitude coordinate of the station where vocalization was recorded | (double)
[11] | "avg_rad" | average radiance; unit = nW/cm^2/sr ([see VIIRS for more info)](#viirs-data)) | (double)
[12] | "rad_cat" | category of radiance, classified has "low", "med", or "high" ([see VIIRS for more info](#viirs-data)) | (string)
[13] | "nightly_cloud_cover_percent" |  mean [cloud_cover (unit = %)](#weather-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[14] | "nightly_cloud_cover_low_percent" | mean [cloud_cover_low (unit = %)](#weather-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[15] | "nightly_cloud_cover_mid_percent" | mean [cloud_cover_mid (unit = %)](#weather-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[16] | "nightly_cloud_cover_high_percent" | mean [cloud_cover_high (unit = %)](#weather-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[17] | "nightly_precipitation_mm" | mean [precipitation (unit = millimeters)](#weather-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[18] | "nightly_rain_mm" | mean [rain (unit = millimeters)](#weather-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[19] | "nightly_snowfall_cm" | mean [snowfall (unit = millimeters)](#weather-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[20] | "mean_moonlight" | mean [moonlight intensity (unit = lux)](#moonlight-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[21] | "median_moonlight" | median [moonlight intensity (unit = lux)](#moonlight-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[22] | "max_moonlight" | max [moonlight intensity (unit = lux)](#moonlight-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[23] | "min_moonlight" | min [moonlight intensity (unit = lux)](#moonlight-data) summarized between [3] `night_start` and [4] `night_end` | (double)
[24] | "midnight_moonlight" | value of [moonlight intensity (unit = lux)](#moonlight-data) at approximately "solar midnight" | (double)

