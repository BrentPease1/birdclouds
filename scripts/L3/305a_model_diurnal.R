################################################################################
### Gilbert X Pease - Bird Cloud Project
### Diurnal Analysis / Modeling
################################################################################

################################################################################
### Read In and Format Data
################################################################################

### Clear workspace and clean up memory:
rm(list = ls())
gc(reset = TRUE)


### Load libraries:
library(data.table)
library(tidyverse)
library(glmmTMB)
library(here)
here::i_am("scripts/L3/305a_model_diurnal.R")

### Read in Data:
# diurn_on <- fread("Data/Final/diurn_on_final.csv")
# diurn_ev <- fread("Data/Final/diurn_ev_final.csv")
dir_304_final_data <- here("data", "L3", "304_final_data")
dir_305_models <- here("data", "L3", "305_models")

## Diurnal:
diurn_on_05 <- readRDS(here(dir_304_final_data, "304a_diurn_on_final_05.rds"))
diurn_on_50 <- readRDS(here(dir_304_final_data, "304d_diurn_on_final_50.rds"))
diurn_ev_05 <- readRDS(here(dir_304_final_data, "304b_diurn_ev_final_05.rds"))
diurn_ev_50 <- readRDS(here(dir_304_final_data, "304e_diurn_ev_final_50.rds"))
diurn_on_05_no_filter <- readRDS(here(
  dir_304_final_data,
  "304_diurn_on_final_05_no_filter.rds"
))
diurn_on_50_no_filter <- readRDS(here(
  dir_304_final_data,
  "304_diurn_on_final_50_no_filter.rds"
))

### Transform the data:
##log transform and scale:

# onset 0.5 grid
diurn_on_05$alan_sc <- scale(log1p(diurn_on_05$avg_rad))
diurn_on_05$cld_sc <- scale(diurn_on_05$sunrise_cloud_cover_percent)
diurn_on_05$family <- as.factor(diurn_on_05$family)
diurn_on_05$precip_sc <- scale(diurn_on_05$sunrise_precipitation_mm)
sum(is.na(diurn_on_05)) #0 - good!

# onset 5.0 grid
diurn_on_50$alan_sc <- scale(log1p(diurn_on_50$avg_rad))
diurn_on_50$cld_sc <- scale(diurn_on_50$sunrise_cloud_cover_percent)
diurn_on_50$family <- as.factor(diurn_on_50$family)
diurn_on_50$precip_sc <- scale(diurn_on_50$sunrise_precipitation_mm)
sum(is.na(diurn_on_50)) #0 - good!

# cess 0.5 grid
diurn_ev_05$alan_sc <- scale(log1p(diurn_ev_05$avg_rad))
diurn_ev_05$cld_sc <- scale(diurn_ev_05$sunset_cloud_cover_percent)
diurn_ev_05$family <- as.factor(diurn_ev_05$family)
diurn_ev_05$precip_sc <- scale(diurn_ev_05$sunset_precipitation_mm)
sum(is.na(diurn_ev_05)) #0 - good!


# cess 5.0 grid
diurn_ev_50$alan_sc <- scale(log1p(diurn_ev_50$avg_rad))
diurn_ev_50$cld_sc <- scale(diurn_ev_50$sunset_cloud_cover_percent)
diurn_ev_50$family <- as.factor(diurn_ev_50$family)
diurn_ev_50$precip_sc <- scale(diurn_ev_50$sunset_precipitation_mm)
sum(is.na(diurn_ev_50)) #0 - good!

# diurn 0.5 grid no filter
diurn_on_05_no_filter$alan_sc <- scale(log1p(diurn_on_05_no_filter$avg_rad))
diurn_on_05_no_filter$cld_sc <- scale(
  diurn_on_05_no_filter$sunrise_cloud_cover_percent
)
diurn_on_05_no_filter$family <- as.factor(diurn_on_05_no_filter$family)
diurn_on_05_no_filter$precip_sc <- scale(
  diurn_on_05_no_filter$sunrise_precipitation_mm
)
sum(is.na(diurn_on_05_no_filter)) #0 - good!


# diurn 5.0 grid no filter
diurn_on_50_no_filter$alan_sc <- scale(log1p(diurn_on_50_no_filter$avg_rad))
diurn_on_50_no_filter$cld_sc <- scale(
  diurn_on_50_no_filter$sunrise_cloud_cover_percent
)
diurn_on_50_no_filter$family <- as.factor(diurn_on_50_no_filter$family)
diurn_on_50_no_filter$precip_sc <- scale(
  diurn_on_50_no_filter$sunrise_precipitation_mm
)
sum(is.na(diurn_on_50_no_filter)) #0 - good!

################################################################################
### Data Analysis
################################################################################
# 100 det filter
######################

##### 0.5 degree models

###### try to get onset model to converge
#Run the model:
mod_on_05 <- glmmTMB::glmmTMB(
  first_onset ~ 1 +
    cld_sc +
    alan_sc +
    precip_sc +
    cld_sc:alan_sc +
    (1 + cld_sc + alan_sc | family) + # remove cld*alan rdm efefct
    (1 | sp_grid_wk),
  data = diurn_on_05
)

#Save model object:
saveRDS(mod_on_05, file = here(dir_305_models, "305a_mod_on_05.rds"))

# when i include the cld*alan rdm effect, i get the following error:
# Warning message:
# In finalizeTMB(TMBStruc, obj, fit, h, data.tmb.old) :
#   Model convergence problem; non-positive-definite Hessian matrix. See vignette('troubleshooting')

### try running alan model structure from science 2025 for comparison
mod_on_alan <- glmmTMB::glmmTMB(
  first_onset ~ 1 + alan_sc + (1 + alan_sc | family / sp_grid_wk),
  data = diurn_on_05
)
saveRDS(mod_on_alan, file = here(dir_305_models, "305_mod_on_alan.rds"))

## cess
mod_ev_alan <- glmmTMB::glmmTMB(
  ev_ces ~ 1 + alan_sc + (1 + alan_sc | family) + (1 | sp_grid_wk),
  data = diurn_ev_05
)
saveRDS(mod_ev_alan, file = here(dir_305_models, "305_mod_ev_alan.rds"))


### try running ev cess model
mod_ev_05 <- glmmTMB::glmmTMB(
  ev_ces ~ 1 +
    cld_sc +
    alan_sc +
    precip_sc +
    cld_sc:alan_sc +
    (1 + cld_sc + alan_sc | family) +
    (1 | sp_grid_wk),
  data = diurn_ev_05
)

#Save the model:
saveRDS(mod_ev_05, file = here(dir_305_models, "305b_mod_ev_05.rds"))


##############################################################################
################################## TO RUN:
##########################

#0.5 deg no filter diurnal onset
mod_on_05_no_filter <- glmmTMB::glmmTMB(
  first_onset ~ 1 +
    cld_sc +
    alan_sc +
    precip_sc +
    cld_sc:alan_sc +
    (1 + cld_sc + alan_sc | family) + # remove cld*alan rdm efefct
    (1 | sp_grid_wk),
  data = diurn_on_05_no_filter
)

#Save model object:
saveRDS(
  mod_on_05_no_filter,
  file = here(dir_305_models, "305_mod_on_05_no_filter.rds")
)


####### 5.0 degree models

## Run onset model:
mod_on_50 <- glmmTMB::glmmTMB(
  first_onset ~ 1 +
    cld_sc +
    alan_sc +
    precip_sc +
    cld_sc:alan_sc +
    (1 + cld_sc + alan_sc | family) + # remove cld*alan rdm efefct
    (1 | sp_grid_wk),
  data = diurn_on_50
)

#Save model object:
saveRDS(mod_on_50, file = here(dir_305_models, "305c_mod_on_50.rds"))

## run ev cess model
mod_ev_50 <- glmmTMB::glmmTMB(
  ev_ces ~ 1 +
    cld_sc +
    alan_sc +
    precip_sc +
    cld_sc:alan_sc +
    (1 + cld_sc + alan_sc | family) +
    (1 | sp_grid_wk),
  data = diurn_ev_50
)

#Save the model:
saveRDS(mod_ev_50, file = here(dir_305_models, "305d_mod_ev_50.rds"))


##5.0 deg no filter diurnal onset
mod_on_50_no_filter <- glmmTMB::glmmTMB(
  first_onset ~ 1 +
    cld_sc +
    alan_sc +
    precip_sc +
    cld_sc:alan_sc +
    (1 + cld_sc + alan_sc | family) + # remove cld*alan rdm efefct
    (1 | sp_grid_wk),
  data = diurn_on_50_no_filter
)

#Save model object:
saveRDS(
  mod_on_50_no_filter,
  file = here(dir_305_models, "305_mod_on_50_no_filter.rds")
)


summary(mod_on_05)
summary(mod_ev_05)
summary(mod_on_alan)
summary(mod_ev_alan)
summary(mod_on_05_no_filter)
summary(mod_on_50)
summary(mod_ev_50)
summary(mod_on_50_no_filter)

### top models
summary(mod_on_50)
summary(mod_ev_50)
