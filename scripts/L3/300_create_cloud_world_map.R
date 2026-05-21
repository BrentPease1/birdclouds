library(terra)
library(sf)
library(ggplot2)
library(tidyterra)
library(here)
library(readr)
library(rnaturalearth)

here::i_am("scripts/L3/300_create_cloud_world_map.R")

# Read cloud data
cloud_raster <- rast("data/L0/MODCF_meanannual.tif")
cloud_raster <- cloud_raster * 0.01
# From `https://www.earthenv.org/cloud`:
#   Mean annual cloud frequency (%) over 2000-2014, mean( ) μm .
#   Valid values range from 010,000 and need to be multiplied by 0.01 to result in % cloudy days.
#   Values greater than 10,000 are used for fill.

# Read birdweather stations
bw_stations <- read_csv("data/L0/stations_mar2026.csv")
bw_stations_sf <- st_as_sf(
  bw_stations,
  coords = c("longitude", "latitude"),
  crs = 4326
)

# Get world map from `rnaturalearth`
world_land <- ne_download(
  scale = 110,
  type = "land",
  category = "physical",
  returnclass = "sf"
)

# Crop and Mask the cloud raster to land
cloud_clipped <- crop(cloud_raster, world_land)
cloud_clipped <- mask(cloud_clipped, world_land)


ggplot() +
  # Plot the clipped cloud cover raster
  geom_spatraster(data = cloud_clipped) +
  scale_fill_distiller(
    name = "Cloud Cover (%)",
    palette = "Greys", # Grey gradient for cloud cover # or Blues # or Greys
    direction = 1, # 1 = light to dark; change to -1 for dark to light
    na.value = "transparent",
    guide = guide_colorbar(
      title.position = "top",
      direction = "horizontal",
      barwidth = unit(4, "cm"),
      barheight = unit(0.3, "cm"),
      order = 1 # Ensures cloud cover comes first
    )
  ) +

  # Plot birdweather stations
  geom_sf(
    data = bw_stations_sf,
    aes(color = "BirdWeather Stations"),
    size = 0.5,
    alpha = 1.0
  ) +
  scale_color_manual(
    name = NULL,
    values = c("BirdWeather Stations" = "#9dd3ad"), # station color #9dd3ad #c35735
    guide = guide_legend(
      direction = "horizontal",
      title.position = "top",
      nrow = 1,
      order = 2
    )
  ) +

  # Clean up the theme, adjust ocean color, and remove axes
  theme_minimal() +
  theme(
    # Set the ocean background color
    panel.background = element_rect(fill = "#abd0e3", color = NA), # or grey #cfcfcf or blue #abd0e3
    panel.grid = element_blank(), # Removes the background lat/lon grid lines

    # Remove other graph stuff
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    axis.title = element_blank(),
    legend.position = "none"

    # # Place legend inside the map
    # legend.position = c(0.15, 0.25),
    # legend.background = element_rect(
    #   fill = alpha("white", 0.8),
    #   color = "gray90"
    # ),
    # legend.box = "vertical",
    # legend.margin = margin(6, 6, 6, 6),
    # legend.title = element_text(size = 9, face = "bold"),
    # legend.text = element_text(size = 8)
  ) +

  coord_sf(xlim = c(-180, 180), ylim = c(-60, 85), expand = FALSE)


# Save output
ggsave(
  "data/L3/300_world_cloud_cover_map.png",
  width = 10,
  height = 6,
  dpi = 300
)
