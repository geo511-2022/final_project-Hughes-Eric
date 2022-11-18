library(sf)
library(tidyverse)
library(ggplot2)
library(sp)
library(ggmap)
library(dodgr)
library(osmdata, quietly=T)
library(classInt)
library(knitr)

##Create Variable with all census tracts within Buffalo boundary that contains median household income data

income_csv <- read.csv(file = "median_income_data_2020.csv",
                              skip = 2, header = F)
income_data <- income_csv[c(1,2,323)]
colnames(income_data) <- c("geoid", "census.tract", "median.household.income")
income_data$geoid = as.character(income_data$geoid)

vehicle_access_csv <- read.csv(file = "vehicle_access.csv")
vehicle_access_data <- vehicle_access_csv[c(1,2,6)]
colnames(vehicle_access_data) <- c("geoid","census.tract","prop.wo.va")

##Create Buffalo border

buffalo_border <- st_read("buffalo_boundary") %>%
  st_transform(4326)
buffalo_sp <- as_Spatial(st_transform(buffalo_border, 4326))
buffalo_bbox <- buffalo_sp@bbox

basemap <- get_stamenmap(
  bbox = buffalo_bbox,
  zoom = 13,
  maptype = "toner-lite")

##Import census tracts and join with median income and vehicle access data

census_tracts <- st_read("buffalo_census_tracts") 

income_shape <- census_tracts %>% left_join(income_data, by = c("GEOID" = "geoid"))
income_shape$INTPTLAT = as.numeric(income_shape$INTPTLAT)
income_shape$INTPTLON = as.numeric(income_shape$INTPTLON)
income_shape$median.household.income = as.integer(income_shape$median.household.income)

vehicle_shape <- census_tracts %>% left_join(vehicle_access_data, by = c("GEOID" = "geoid"))
vehicle_shape$INTPTLAT = as.numeric(vehicle_shape$INTPTLAT)
vehicle_shape$INTPTLON = as.numeric(vehicle_shape$INTPTLON)
vehicle_shape$prop.wo.va = as.double(vehicle_shape$prop.wo.va)

##Project data

income_proj <- income_shape %>% 
  st_transform(4326) 

vehicle_proj <- vehicle_shape %>% 
  st_transform(4326) 

##Plot median income

income_map <- ggplot(income_proj) + 
  geom_sf(data = income_proj, aes(x = INTPTLON, y = INTPTLAT,  fill = median.household.income), 
          inherit.aes = F) +
  scale_fill_gradient(low = "yellow", high = "red") +
  geom_sf(fill = "transparent", color = "gray20", size = 1, 
          data = buffalo_border, inherit.aes = F)+
  coord_sf(ylim=buffalo_bbox[c(2,4)], xlim=buffalo_bbox[c(1,3)]) +
  labs(title="Median Household Income in Buffalo, NY (2020)",
       subtitle="Census Tract Scale",
       caption="Data from US Census Bureau",
       x = "Longitude",
       y = "Latitude") +
  theme(axis.text.x = element_text(angle = 45, vjust = 0.9, hjust=1))+
  guides(fill=guide_legend(title="Median Household Income ($)")) 

income_map

##Plot vehicle access

vehicle_map <- ggplot(vehicle_proj) + 
  geom_sf(data = vehicle_proj, aes(x = INTPTLON, y = INTPTLAT,  fill = prop.wo.va), 
          inherit.aes = F) +
  scale_fill_gradient(low = "#f1eef6", high = "#ce1256") +
  geom_sf(fill = "transparent", color = "gray20", size = 1, 
          data = buffalo_border, inherit.aes = F)+
  coord_sf(ylim=buffalo_bbox[c(2,4)], xlim=buffalo_bbox[c(1,3)]) +
  labs(title="Proportion of households without access to a vehicle in Buffalo, NY (2020)",
       subtitle="Census Tract Scale",
       caption="Data from US Census Bureau",
       x = "Longitude",
       y = "Latitude") +
  theme(axis.text.x = element_text(angle = 45, vjust = 0.9, hjust=1))+
  guides(fill=guide_legend(title="Proportion of households 
without access to a vehicle")) 

vehicle_map

#Centroid of census tracts

st_cent <- st_centroid(income_proj)

##Buffalo Supermarkets

#Create a 0.5-mile border around Buffalo
border_poly <- buffalo_border %>%
  st_cast("POLYGON")
buffer_buffalo <- st_buffer(border_poly, dist = 804.672)

#Select all the supermarkets within the new border
buffalo_supermarkets <- st_read("erie_county_supermarkets")%>%
  st_crop(buffer_buffalo)

#Create X and Y columns in buffalo_supermarkets and centroid data
coords = st_coordinates(buffalo_supermarkets)
xlon = coords[,1]
ylat = coords[,2]
bf_supermarkets <- buffalo_supermarkets %>%
  mutate(xlon,ylat) 

sf_coords <- st_as_sf(st_cent) 
cen_coords <- st_coordinates(sf_coords)
xlon = cen_coords[,1]
ylat = cen_coords[,2]

centroids <- sf_coords %>%
  mutate(xlon,ylat) %>%
  st_transform(4326)
centroids$id <- 1:max(nrow(centroids))

#Plot median income map with supermarkets

income_supermarket <- ggmap(basemap) +
  geom_sf(data = income_proj, aes(x = INTPTLON, y = INTPTLAT,  fill = median.household.income), 
          inherit.aes = F)+
  scale_fill_gradient(low = "yellow", high = "red") +
  geom_point(data = bf_supermarkets, aes(x = xlon, y = ylat, color = "Supermarket"), size = 3) +
  scale_color_manual(values = "green", name = "Supermarkets") +
  labs(title="All supermarkets within 0.5-miles of Buffalo, NY (2020)",
       subtitle="Median income data",
       caption="Median household income data from US Census Bureau,
       supermarket data from Data Axle",
       x = "Longitude",
       y = "Latitude") +
  theme(legend.direction = "vertical", axis.text.x = element_text(angle = 45, vjust = 0.9, hjust=1))+
  guides(fill=guide_legend(title="Median Household Income ($)"))
income_supermarket  

#Plot vehicle access data map with supermarkets

vehicle_supermarket <- ggmap(basemap) +
  geom_sf(data = vehicle_proj, aes(x = INTPTLON, y = INTPTLAT,  fill = prop.wo.va), 
          inherit.aes = F)+
  scale_fill_gradient(low = "#f1eef6", high = "#ce1256") +
  geom_point(data = bf_supermarkets, aes(x = xlon, y = ylat, color = "Supermarket"), size = 3) +
  scale_color_manual(values = "green", name = "Supermarkets") +
  labs(title="All supermarkets within 0.5-miles of Buffalo, NY (2020)",
       subtitle="Proportion of households without vehicle access",
       caption="Vehicle access data from US Census Bureau,
       supermarket data from Data Axle",
       x = "Longitude",
       y = "Latitude") +
  theme(legend.direction = "vertical", axis.text.x = element_text(angle = 45, vjust = 0.9, hjust=1))+
  guides(fill=guide_legend(title="Proportion of households 
without access to a vehicle")) 
vehicle_supermarket

## Distance from centroid to nearest supermarket
# Define Buffalo coordinate variable
xy_coords <- rbind (
  c (-78.79514, 42.96641), # Buffalo
  c (-78.91252, 42.82610)
) # Buffalo
xy <- data.frame (lon = xy_coords [, 1], lat = xy_coords [, 2])

#Calculate distances from centroids to supermarkets

buffalo_network <- dodgr_streetnet (pts = xy, expand = 0.2, quiet = FALSE)
graph <- weight_streetnet (buffalo_network, wt_profile = "motorcar")
graph <- graph [which (graph$component == 1), ]
from_x <- centroids$INTPTLON
from_y <- centroids$INTPTLAT
to_x <- bf_supermarkets$xlon
to_y <- bf_supermarkets$ylat
d <- dodgr_dists(graph = graph, from = cbind (from_x, from_y), to = cbind (to_x, to_y))
df <- apply(d, 1, FUN=min, na.rm=TRUE) %>% as.data.frame()
b <- st_sf(data.frame(centroids, df))
names(b)[20] <- "dist"

##Create income brackets

# Switch distance variable back to dataframe
b_df <- as_data_frame(b)

##Create brackets and join distance calculations
#Median income brackets
less_than_20k <- income_proj %>%
  filter(median.household.income <= 20000) %>%
  left_join(b_df, by = c("GEOID" = "GEOID"))

less_than_40k <- income_proj %>%
  filter(median.household.income > 20000, median.household.income <= 40000) %>%
  left_join(b_df, by = c("GEOID" = "GEOID"))

less_than_60k <- income_proj %>%
  filter(median.household.income > 40000, median.household.income <= 60000) %>%
  left_join(b_df, by = c("GEOID" = "GEOID"))

greater_than_or_equal_60k <- income_proj %>%
  filter(median.household.income >= 60000) %>%
  left_join(b_df, by = c("GEOID" = "GEOID"))

#Vehicle access brackets
less_than_0.2 <- vehicle_proj %>%
  filter(prop.wo.va <= 0.2) %>%
  left_join(b_df, by = c("GEOID" = "GEOID"))

less_than_0.4 <- vehicle_proj %>%
  filter(prop.wo.va > 0.2, prop.wo.va <= 0.4) %>%
  left_join(b_df, by = c("GEOID" = "GEOID"))

less_than_0.6 <- vehicle_proj %>%
  filter(prop.wo.va > 0.4, prop.wo.va <= 0.6) %>%
  left_join(b_df, by = c("GEOID" = "GEOID"))

greater_than_0.6 <- vehicle_proj %>%
  filter(prop.wo.va > 0.6) %>%
  left_join(b_df, by = c("GEOID" = "GEOID"))

## Calculate average distance for each bracket in meters

ave_dist_less_than_20k <- mean(less_than_20k$dist) #1813.465
ave_dist_less_than_40k <- mean(less_than_40k$dist) #1926.935
ave_dist_less_than_60k <- mean(less_than_60k$dist) #1830.889
ave_dist_greater_than_60k <- mean(greater_than_or_equal_60k$dist) #1648.723

ave_dist_income <- c(ave_dist_less_than_20k,ave_dist_less_than_40k,ave_dist_less_than_60k,ave_dist_greater_than_60k)

knitr::kable(head(arrange(data[,1:2], desc(year))), 
             format = "simple", col.names = c("Year", "Mean"), caption = "<span style='font-size:20px'>Top 5 CO2 Levels")

ave_dist_less_than_0.2 <- mean(less_than_0.2$dist) #1661.945
ave_dist_less_than_0.4 <- mean(less_than_0.4$dist) #1844.538
ave_dist_less_than_0.6 <- mean(less_than_0.6$dist) #1957.577
ave_dist_greater_than_0.6 <- mean(greater_than_0.6$dist) #2438.269


