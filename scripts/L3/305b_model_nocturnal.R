### Load libraries:
library(data.table)
library(tidyverse)
library(glmmTMB)
library(here)
here::i_am("scripts/L3/305b_model_nocturnal.R")

### Read in Data:
dir_304_final_data <- here("data", "L3", "304_final_data")
dir_305_models <- here("data", "L3", "305_models")

noc_final_05 <- readRDS(here(dir_304_final_data, "304c_noc_final_05.rds"))
noc_final_50 <- readRDS(here(dir_304_final_data, "304f_noc_final_50.rds"))

# Scale variables for modeling
noc_final_05$alan <- log1p(noc_final_05$avg_rad)
noc_final_05$alan_sc <- scale(noc_final_05$alan)
noc_final_05$cloud_sc <- scale(noc_final_05$nightly_cloud_cover_percent)
noc_final_05$precip_sc <- scale(noc_final_05$nightly_precipitation_mm)

noc_final_50$alan <- log1p(noc_final_50$avg_rad)
noc_final_50$alan_sc <- scale(noc_final_50$alan)
noc_final_50$cloud_sc <- scale(noc_final_50$nightly_cloud_cover_percent)
noc_final_50$precip_sc <- scale(noc_final_50$nightly_precipitation_mm)


# Species differ in the linear ALAN-cloud interaction  -->   CONVERGED
#mod_step5

# 0.5 degree grid
mod_noc_05 <- glmmTMB(
  det ~ 1 +
    (alan_sc + I(alan_sc^2)) * cloud_sc +
    precip_sc +
    (1 + alan_sc + I(alan_sc^2) + cloud_sc + alan_sc:cloud_sc | common_name) +
    (1 | sp_grid_wk),
  family = binomial,
  data = noc_final_05
)

#Save model object:
saveRDS(mod_noc_05, file = here(dir_305_models, "305i_mod_noc_05.rds"))

# 5.0 degree grid
mod_noc_50 <- glmmTMB(
  det ~ 1 +
    (alan_sc + I(alan_sc^2)) * cloud_sc +
    precip_sc +
    (1 + alan_sc + I(alan_sc^2) + cloud_sc + alan_sc:cloud_sc | common_name) +
    (1 | sp_grid_wk),
  family = binomial,
  data = noc_final_50
)


#Save model object:
saveRDS(mod_noc_50, file = here(dir_305_models, "305j_mod_noc_50.rds"))


########## trying something illegal
#noc_final_05$mean_moonlight_sc <- scale(noc_final_05$mean_moonlight)
# 0.5 degree grid
mod_noc_05_mn <- glmmTMB(
  ### Trying moonlight * ALAN interaction (doesnt converge w/ or w/o alan*mn slope)
  # det ~ 1 +
  #   (alan_sc + I(alan_sc^2)) * cloud_sc +
  #   mean_moonlight_sc * alan_sc +
  #   (1 +
  #     alan_sc +
  #     I(alan_sc^2) +
  #     cloud_sc +
  #     alan_sc:cloud_sc +
  #     mean_moonlight_sc |
  #     common_name) +
  #   (1 | sp_grid_wk),

  ## try moon*ALAN*cld with moonlight slope
  det ~ 1 +
    (alan_sc + I(alan_sc^2)) * cloud_sc * mean_moonlight_sc +
    (1 +
      alan_sc +
      I(alan_sc^2) +
      cloud_sc +
      alan_sc:cloud_sc +
      mean_moonlight_sc | # adding moonlight slope
      common_name) +
    (1 | sp_grid_wk),

  ##MOONLIGHT FIXED EFFECT + RDM SLOPE CONVERGED!!!
  # det ~ 1 +
  #   (alan_sc + I(alan_sc^2)) * cloud_sc +
  #   mean_moonlight_sc + # keeping moonlight fixed
  #   (1 +
  #     alan_sc +
  #     I(alan_sc^2) +
  #     cloud_sc +
  #     alan_sc:cloud_sc +
  #     mean_moonlight_sc | # adding moonlight slope
  #     common_name) +
  #   (1 | sp_grid_wk),
  family = binomial,
  data = noc_final_05
)

### CONVERGED BUT MOON*CLD NOT SIGNIFICANT
#  det ~ 1 +
#     (alan_sc + I(alan_sc^2)) * cloud_sc +
#     mean_moonlight_sc * cloud_sc +
#     (1 +
#       alan_sc +
#       I(alan_sc^2) +
#       cloud_sc +
#       alan_sc:cloud_sc  |
#       common_name) +
#     (1 | sp_grid_wk),

# det ~ 1 +
#     (alan_sc + I(alan_sc^2)) * cloud_sc +
#     mean_moonlight_sc * cloud_sc * alan_sc +
#     (1 + alan_sc + I(alan_sc^2) + cloud_sc + alan_sc:cloud_sc + mean_moonlight_sc | common_name) +
#     (1 | sp_grid_wk),
#   family = binomial,
#   data = noc_final_05

# convergence issues: (1 + alan_sc + cloud_sc || common_name)
