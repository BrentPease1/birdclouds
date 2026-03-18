
# final_data_metadata.md

This file describes the data contained in the final data files prepared
for modelling and analyses, including [**final_diurnal.RData**]() and
[**final_nocturnal.RData**](). Note that the exact same datasets are also
provided with different extensions: `.csv` or `.rds`


To Do
* [ ] Write metadata for nocturnal dataset
* [x] Write metadata for weather data
* [x] Write metadata for VIIRS



## VIIRS information

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
# pulled from the VIIRS script
# categorize nighttime light
out[, rad_cat := fcase(
  avg_rad < quantile(avg_rad, probs = 0.334, na.rm = T), "low",
  avg_rad >= quantile(avg_rad, probs = 0.334, na.rm = T) & avg_rad < quantile(avg_rad, probs = 0.667, na.rm = T), "med",
  avg_rad >= quantile(avg_rad, probs = 0.667, na.rm = T), "high"
)]
```


## Weather information

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

## **final_diurnal.RData**

[**final_diurnal.RData**]() is the final dataset used for diurnal modelling
analyses. The dataset contains 30 columns. The names, descriptions, and data
classes of each column are described below:

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
[11] | `avg_rad` | average radiance; unit = nW/cm^2/sr [(see VIIRS for more info)](#viirs-information) | (double)
[12] | `rad_cat` | category of radiance, classified has "low", "med", or "high" [(see VIIRS for more info)](#viirs-information) | (string)
[13] | `sunrise` | date and time of sunrise on the [3] `date_time` of the vocalization in UTC timezone | (POSIXct)
[14] | `sunset` | date and time of sunset on the [3] `date_time` of the vocalization in UTC timezone | (POSIXct)
[15] | `first_onset` | [time of first vocalization detection minus time of local sunrise] | (double)
[16] | `median_dawn` | [time of 50% vocalization detection minus time of local sunrise] | (double)
[17] | `sunrise_cloud_cover_percent` | mean [cloud_cover (unit = %)](#weather-information) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[18] | `sunrise_cloud_cover_low_percent` | mean [cloud_cover_low (unit = %)](#weather-information) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[19] | `sunrise_cloud_cover_mid_percent` | mean [cloud_cover_mid (unit = %)](#weather-information) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[20] | `sunrise_cloud_cover_high_percent` | mean [cloud_cover_high (unit = %)](#weather-information) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[21] | `sunrise_precipitation_mm` | mean [precipitation (unit = millimeters)](#weather-information) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[22] | `sunrise_rain_mm` | mean [rain (unit = millimeters)](#weather-information) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[23] | `sunrise_snowfall_cm` | mean [snowfall (unit = millimeters)](#weather-information) summarized for a 3-hr window around sunrise (i.e., average weather for 1hr before sunrise, sunrise, and 1 hr after sunrise) | (double)
[24] | `sunset_cloud_cover_percent` | mean [cloud_cover (unit = %)](#weather-information) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[25] | `sunset_cloud_cover_low_percent` | mean [cloud_cover_low (unit = %)](#weather-information) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[26] | `sunset_cloud_cover_mid_percent` | mean [cloud_cover_mid (unit = %)](#weather-information) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[27] | `sunset_cloud_cover_high_percent` | mean [cloud_cover_high (unit = %)](#weather-information) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[28] | `sunset_precipitation_mm` | mean [precipitation (unit = millimeters)](#weather-information) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[29] | `sunset_rain_mm` | mean [rain (unit = millimeters)](#weather-information) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)
[30] | `sunset_snowfall_cm` | mean [snowfall (unit = millimeters)](#weather-information) summarized for a 3-hr window around sunset (i.e., average weather for 1hr before sunset, sunset, and 1 hr after sunset) | (double)


## **final_nocturnal.RData**

[**final_diurnal.RData**]() is the final dataset used for nocturnal modelling analyses.
The dataset contains X columns, with each column name and class described below: