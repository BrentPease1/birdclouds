################################################################################
### Gilbert X Pease - Bird Cloud Project
### Data Visualization, Main Results - Figure 3
### Diurnal and Nocturnal Combined
################################################################################

### Clear workspace and clean up memory:
rm(list = ls())
gc(reset = TRUE)

### Load libraries:
library(data.table)
library(tidyverse)
library(glmmTMB)
library(MetBrewer)
library(patchwork)
library(here)
here::i_am("scripts/L3/306_visualize_fig3.R")

### Read in Data:
dir_304_final_data <- here("data", "L3", "304_final_data")
dir_305_models <- here("data", "L3", "305_models")
dir_306_fig3 <- here("data", "L3", "306_fig3")

## Occurrence data:
diurn_on <- readRDS(here(dir_304_final_data, "304d_diurn_on_final_50.rds"))
diurn_ev <- readRDS(here(dir_304_final_data, "304e_diurn_ev_final_50.rds"))
noc <- readRDS(here(dir_304_final_data, "304f_noc_final_50.rds"))

## Model objects:
m_on <- readRDS(here(dir_305_models, "305c_mod_on_50.rds"))
m_ev <- readRDS(here(dir_305_models, "305d_mod_ev_50.rds"))
m_noc <- readRDS(here(dir_305_models, "305j_mod_noc_50.rds"))

color_palette <- c(
  "Clouds" = "#8997af",
  "No Clouds" = "#272526"
)

### Process Data:

## log transform and scale:
diurn_on$alan_sc <- scale(log1p(diurn_on$avg_rad))
diurn_on$cld_sc <- scale(diurn_on$sunrise_cloud_cover_percent)
diurn_on$family <- as.factor(diurn_on$family)
diurn_on$precip_sc <- scale(diurn_on$sunrise_precipitation_mm)

diurn_ev$alan_sc <- scale(log1p(diurn_ev$avg_rad))
diurn_ev$cld_sc <- scale(diurn_ev$sunset_cloud_cover_percent)
diurn_ev$family <- as.factor(diurn_ev$family)
diurn_ev$precip_sc <- scale(diurn_ev$sunset_precipitation_mm)

noc$alan_sc <- scale(log1p(noc$avg_rad))
noc$cld_sc <- scale(noc$nightly_cloud_cover_percent)
noc$family <- as.factor(noc$family)
noc$precip_sc <- scale(noc$nightly_precipitation_mm)


## Create scaled variables from dataframes, maintaining attributes:
alan.sca.on <- scale(log1p(diurn_on$avg_rad))
cld.sca.on <- scale(diurn_on$sunrise_cloud_cover_percent)
precip.sca.on <- scale(diurn_on$sunrise_precipitation_mm)

alan.sca.ev <- scale(log1p(diurn_ev$avg_rad))
cld.sca.ev <- scale(diurn_ev$sunset_cloud_cover_percent) #Had an error here! Fixed.
precip.sca.ev <- scale(diurn_ev$sunset_precipitation_mm)

alan.sca.noc <- scale(log1p(noc$avg_rad))
cld.sca.noc <- scale(noc$nightly_cloud_cover_percent)
precip.sca.noc <- scale(noc$nightly_precipitation_mm)


## Calculate the scaled value representing 0 mm of precipitation:
precip_0_on <- (0 - attr(precip.sca.on, "scaled:center")) /
  attr(precip.sca.on, "scaled:scale")
precip_0_ev <- (0 - attr(precip.sca.ev, "scaled:center")) /
  attr(precip.sca.ev, "scaled:scale")
precip_0_noc <- (0 - attr(precip.sca.noc, "scaled:center")) /
  attr(precip.sca.noc, "scaled:scale")


### Prep data for visualization:

## Pop Level Model Visualization:
data_on <- tidyr::expand_grid(
  alan_sc = seq(
    from = min(diurn_on$alan_sc),
    to = max(diurn_on$alan_sc),
    length.out = 20
  ),
  cld_sc = c(min(diurn_on$cld_sc), max(diurn_on$cld_sc)),
  precip_sc = precip_0_on
)

data_ev <- tidyr::expand_grid(
  alan_sc = seq(
    from = min(diurn_ev$alan_sc),
    to = max(diurn_ev$alan_sc),
    length.out = 20
  ),
  cld_sc = c(min(diurn_ev$cld_sc), max(diurn_ev$cld_sc)),
  precip_sc = precip_0_ev
)

data_noc <- tidyr::expand_grid(
  alan_sc = seq(
    from = min(noc$alan_sc, na.rm = TRUE),
    to = max(noc$alan_sc, na.rm = TRUE),
    length.out = 200
  ),
  cloud_sc = c(min(noc$cld_sc, na.rm = TRUE), max(noc$cld_sc, na.rm = TRUE)),
  precip_sc = precip_0_noc
)


## Make prediction/projection from model objects and above data subsets:
## fit model to above data, giving it a range of vals to predict to.
pred_on <- predict(
  m_on,
  data_on,
  se.fit = TRUE,
  type = "response",
  re.form = NA
)

pred_ev <- predict(
  m_ev,
  data_ev,
  se.fit = TRUE,
  type = "response",
  re.form = NA
)

pred_noc <- predict(m_noc, data_noc, se.fit = TRUE, type = "link", re.form = NA)

################
### Save the prediction objects for later because they take a long time to predict
saveRDS(pred_on, file = here(dir_306_fig3, "306a_pred_on.rds"))
saveRDS(pred_ev, file = here(dir_306_fig3, "306b_pred_ev.rds"))
saveRDS(pred_noc, file = here(dir_306_fig3, "306c_pred_noc.rds"))
### Read in the prediction objects
pred_on <- readRDS(here(dir_306_fig3, "306a_pred_on.rds"))
pred_ev <- readRDS(here(dir_306_fig3, "306b_pred_ev.rds"))
pred_noc <- readRDS(here(dir_306_fig3, "306c_pred_noc.rds"))
################

## Reformat and backtransform data:
plot_data_on <-
  data_on |>
  tibble::add_column(fit = pred_on$fit, se = pred_on$se.fit) |>
  mutate(
    cld = cld_sc *
      attr(cld.sca.on, "scaled:scale") +
      attr(cld.sca.on, "scaled:center"), #backtransforming data to original scale
    alan = alan_sc *
      attr(alan.sca.on, "scaled:scale") +
      attr(alan.sca.on, "scaled:center")
  ) |>
  #mutate(cld_lab = ifelse(cld > 0, 'cloudy', 'clear')) |> # Removed by Karina
  mutate(cld_lab = ifelse(cld == min(cld), 'No Clouds', 'Clouds')) |> # Added by Karina
  tibble::add_column(period = "onset")

plot_data_ev <-
  data_ev |>
  tibble::add_column(fit = pred_ev$fit, se = pred_ev$se.fit) |>
  mutate(
    cld = cld_sc *
      attr(cld.sca.ev, "scaled:scale") +
      attr(cld.sca.ev, "scaled:center"), #backtransforming data to original scale
    alan = alan_sc *
      attr(alan.sca.ev, "scaled:scale") +
      attr(alan.sca.ev, "scaled:center")
  ) |>
  #mutate(cld_lab = ifelse(cld > 0, 'cloudy', 'clear')) |> # Removed by Karina
  mutate(cld_lab = ifelse(cld == min(cld), 'No Clouds', 'Clouds')) |> # Added by Karina
  tibble::add_column(period = "cessation")

plot_data_noc <-
  data_noc |>
  # tibble::add_column(fit = pred_noc$fit,
  #                    se = pred_noc$se.fit) |>
  tibble::add_column(
    # Calculate intervals on the link scale
    fit_link = pred_noc$fit,
    lwr_link = pred_noc$fit - (1.96 * pred_noc$se.fit), # 95% CI lower
    upr_link = pred_noc$fit + (1.96 * pred_noc$se.fit) # 95% CI upper
  ) |>
  mutate(
    # Back-transform to probabilities using plogis()
    fit = plogis(fit_link),
    lwr = plogis(lwr_link),
    upr = plogis(upr_link),

    # backtransforming data to original scale
    cld = cloud_sc *
      attr(cld.sca.noc, "scaled:scale") +
      attr(cld.sca.noc, "scaled:center"),
    alan = alan_sc *
      attr(alan.sca.noc, "scaled:scale") +
      attr(alan.sca.noc, "scaled:center")
  ) |>
  #mutate(cld_lab = ifelse(cld > 0, 'cloudy', 'clear')) |> # Removed by Karina
  mutate(cld_lab = ifelse(cld == min(cld), 'No Clouds', 'Clouds')) |> # Added by Karina
  tibble::add_column(period = "nocturnal")


### Create the plots:

## Figure 3 v1 (diurnal plots scaled to 0):

## Diurnal Onset:
plot_on <-
  ggplot(
    data = plot_data_on,
    aes(x = alan, y = fit, color = factor(cld_lab))
  ) +
  # geom_ribbon(aes(ymin = fit - se,
  #                 ymax = fit + se,
  #                 fill = factor(cld_lab),
  #             color = NA,
  #             alpha = 0.3) +
  # 95% CI
  geom_ribbon(
    aes(ymin = fit - 1.96 * se, ymax = fit + 1.96 * se, fill = factor(cld_lab)),
    color = NA,
    alpha = 0.2
  ) +
  geom_line(linewidth = 1) +
  scale_color_manual(values = color_palette) +
  scale_fill_manual(values = color_palette) +
  scale_y_continuous(
    limits = c(0, 3),
    breaks = seq(0, 3, by = 0.5)
  ) +
  # Zero baseline reference line
  geom_hline(
    yintercept = 0,
    linetype = "dashed",
    color = "grey60",
    linewidth = 0.4
  ) +
  annotate(
    "segment",
    x = min(plot_data_on$alan),
    xend = min(plot_data_on$alan),
    y = 0.1,
    yend = 0.5,
    arrow = arrow(length = unit(0.2, "cm")),
    color = "grey30"
  ) +
  annotate(
    "text",
    x = 0.25,
    y = 0.25,
    label = "Hours After Sunrise",
    hjust = 0,
    size = 3,
    fontface = "italic",
    color = "grey20"
  ) +
  labs(
    title = "A) Diurnal Onset",
    x = "Light Pollution",
    y = "Vocal Onset\n(hours relative to sunrise)",
    fill = "cld_lab",
    color = "cld_lab"
  ) +
  theme_minimal() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.2),
    panel.grid = element_blank(),
    text = element_text(size = 10),
    legend.title = element_blank(),
    legend.position = "none",
    plot.title = element_text(
      size = 10,
      vjust = 5,
      face = "bold",
      margin = margin(t = 15)
    ),
    axis.title.x = element_blank(),
    axis.title.y = element_text(size = 9, margin = margin(r = 5)),
  )


## Diurnal Cessation
plot_ev <-
  ggplot(
    data = plot_data_ev,
    aes(x = alan, y = fit, color = factor(cld_lab))
  ) +
  # geom_ribbon(aes(ymin = fit - se,
  #                 ymax = fit + se,
  #                 fill = factor(cld_lab)), color = NA, alpha = 0.3) +
  # 95% CI
  geom_ribbon(
    aes(ymin = fit - 1.96 * se, ymax = fit + 1.96 * se, fill = factor(cld_lab)),
    color = NA,
    alpha = 0.2
  ) +
  geom_line(linewidth = 1) +
  scale_color_manual(values = color_palette) +
  scale_fill_manual(values = color_palette) +
  scale_y_continuous(
    limits = c(0, -3),
    breaks = seq(0, -3, by = -0.5)
  ) +
  # Zero baseline reference line
  geom_hline(
    yintercept = 0,
    linetype = "dashed",
    color = "grey60",
    linewidth = 0.4
  ) +
  annotate(
    "segment",
    x = min(plot_data_ev$alan),
    xend = min(plot_data_ev$alan),
    y = -0.1,
    yend = -0.5,
    arrow = arrow(length = unit(0.2, "cm")),
    color = "grey30"
  ) +
  annotate(
    "text",
    x = 0.25,
    y = -0.25,
    label = "Hours Before Sunset",
    hjust = 0,
    size = 3,
    fontface = "italic",
    color = "grey20"
  ) +
  labs(
    title = "B) Diurnal Cessation",
    x = "Light Pollution",
    y = "Vocal Cessation\n(hours relative to sunset)",
    fill = "cld_lab",
    color = "cld_lab"
  ) +
  theme_minimal() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.2),
    panel.grid = element_blank(),
    text = element_text(size = 10),
    legend.title = element_blank(),
    legend.position = "none",
    plot.title = element_text(
      size = 10,
      face = "bold",
      vjust = 5,
      margin = margin(t = 15)
    ),
    axis.title.x = element_text(size = 10, margin = margin(t = 15)),
    axis.title.y = element_text(size = 9, margin = margin(r = 5)),
  )


## Nocturnal
plot_noc <-
  ggplot(
    data = plot_data_noc,
    aes(x = alan, y = fit, color = factor(cld_lab))
  ) +
  # geom_ribbon(aes(ymin = fit - se,
  #                 ymax = fit + se,
  #                 fill = factor(cld_lab)), color = NA, alpha = 0.3) +
  geom_ribbon(
    aes(ymin = lwr, ymax = upr, fill = factor(cld_lab)),
    color = NA,
    alpha = 0.2
  ) +
  geom_line(linewidth = 1) +
  scale_color_manual(values = color_palette) +
  scale_fill_manual(values = color_palette) +
  labs(
    title = "C) Nocturnal Night Period",
    x = "Light Pollution",
    y = "Probability of Vocalization",
    fill = "cld_lab",
    color = "cld_lab"
  ) +
  theme_minimal() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.2),
    panel.grid = element_blank(),
    text = element_text(size = 10),
    legend.title = element_blank(),
    plot.title = element_text(
      size = 10,
      vjust = 5,
      face = "bold",
      margin = margin(t = 15)
    ),
    axis.title.x = element_blank(),
    axis.title.y = element_text(size = 9, margin = margin(r = 5)),
  )


### Putting them all together:
Fig3_v1 <- plot_on + plot_ev + plot_noc

ggsave(
  Fig3_v1,
  filename = here(dir_306_fig3, "306d_Fig3_v2.png"),
  device = "png",
  height = 3,
  width = 8,
  units = "in",
  dpi = 600
)

# ## Figure 3 v2 (diurnal plots default scaling):

# ## Diurnal Onset:
# plot_on <-
#   ggplot(
#     data = plot_data_on,
#     aes(x = alan, y = fit, color = factor(cld_lab))
#   ) +
#   # geom_ribbon(aes(ymin = fit - se,
#   #                 ymax = fit + se,
#   #                 fill = factor(cld_lab)),
#   #             color = NA,
#   #             alpha = 0.3) +
#   # 95% CI
#   geom_ribbon(
#     aes(ymin = fit - 1.96 * se, ymax = fit + 1.96 * se, fill = factor(cld_lab)),
#     color = NA,
#     alpha = 0.3
#   ) +
#   geom_line(linewidth = 1) +
#   scale_color_manual(
#     values = c("#272526", "#8997af")
#   ) +
#   scale_fill_manual(
#     values = c("#272526", "#8997af")
#   ) +
#   labs(
#     title = "A.) Diurnal - Onset",
#     x = expression(atop(
#       bold("Light Pollution")
#     )),
#     y = "Vocal Onset\n(hours relative to sunrise)",
#     fill = "cld_lab",
#     color = "cld_lab"
#   ) +
#   theme_minimal() +
#   theme(
#     axis.line = element_line(color = "black", linewidth = 0.2),
#     panel.grid = element_blank(),
#     text = element_text(size = 10),
#     legend.title = element_blank(),
#     legend.position = "none",
#     plot.title = element_text(
#       size = 10,
#       vjust = 5,
#       face = "bold",
#       margin = margin(t = 15)
#     ),
#     axis.title.x = element_blank(),
#     axis.title.y = element_text(size = 9, margin = margin(r = 5)),
#   )

# ## Diurnal Cessation
# plot_ev <-
#   ggplot(
#     data = plot_data_ev,
#     aes(x = alan, y = fit, color = factor(cld_lab))
#   ) +
#   # geom_ribbon(aes(ymin = fit - se,
#   #                 ymax = fit + se,
#   #                 fill = factor(cld_lab)), color = NA, alpha = 0.3) +
#   # 95% CI
#   geom_ribbon(
#     aes(ymin = fit - 1.96 * se, ymax = fit + 1.96 * se, fill = factor(cld_lab)),
#     color = NA,
#     alpha = 0.3
#   ) +
#   geom_line(linewidth = 1) +
#   scale_color_manual(
#     values = c("#272526", "#8997af")
#   ) +
#   scale_fill_manual(
#     values = c("#272526", "#8997af")
#   ) +
#   labs(
#     title = "B.) Diurnal - Evening Cessation",
#     x = "Light Pollution",
#     y = "Vocal Cessation\n(hours relative to sunset)",
#     fill = "cld_lab",
#     color = "cld_lab"
#   ) +
#   theme_minimal() +
#   theme(
#     axis.line = element_line(color = "black", linewidth = 0.2),
#     panel.grid = element_blank(),
#     text = element_text(size = 10),
#     legend.title = element_blank(),
#     legend.position = "none",
#     plot.title = element_text(
#       size = 10,
#       face = "bold",
#       vjust = 5,
#       margin = margin(t = 15)
#     ),
#     axis.title.x = element_text(size = 10, margin = margin(t = 15)),
#     axis.title.y = element_text(size = 9, margin = margin(r = 5)),
#   )

# ## Nocturnal
# plot_noc <-
#   ggplot(
#     data = plot_data_noc,
#     aes(x = alan, y = fit, color = factor(cld_lab))
#   ) +
#   # geom_ribbon(aes(ymin = fit - se,
#   #                 ymax = fit + se,
#   #                 fill = factor(cld_lab)), color = NA, alpha = 0.3) +
#   geom_ribbon(
#     aes(ymin = lwr, ymax = upr, fill = factor(cld_lab)),
#     color = NA,
#     alpha = 0.3
#   ) +
#   geom_line(linewidth = 1) +
#   scale_color_manual(
#     values = c("#272526", "#8997af")
#   ) +
#   scale_fill_manual(
#     values = c("#272526", "#8997af")
#   ) +
#   labs(
#     title = "C) Nocturnal Night Period",
#     x = "Light Pollution",
#     y = "Probability of Vocalization",
#     fill = "cld_lab",
#     color = "cld_lab"
#   ) +
#   theme_minimal() +
#   theme(
#     axis.line = element_line(color = "black", linewidth = 0.2),
#     panel.grid = element_blank(),
#     text = element_text(size = 10),
#     legend.title = element_blank(),
#     plot.title = element_text(
#       size = 10,
#       vjust = 5,
#       face = "bold",
#       margin = margin(t = 15)
#     ),
#     axis.title.x = element_blank(),
#     axis.title.y = element_text(size = 9, margin = margin(r = 5)),
#   )

# ### Putting them all together:
# Fig3_v2 <- plot_on + plot_ev + plot_noc

# ggsave(
#   Fig3_v2,
#   #filename = "Data/Final/Fig3_v2.png",
#   filename = here(dir_306_fig3, "306e_Fig3_v2.png"),
#   device = "png",
#   height = 3,
#   width = 8,
#   units = "in",
#   dpi = 600
# )
