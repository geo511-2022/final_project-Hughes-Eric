library(sf)
library(tidyverse)
library(ggplot2)
library(rgeos)
library(sp)
library(ggmap)

#import median income data

raw_median_income <- read.csv(file = "C:/Users/17166/OneDrive - University at Buffalo/Desktop/Fall Semester 2022/GEO 511/Final Project/median household income2020 census/ACSST5Y2020.S1903-Data.csv",
                              skip = 2, header = F)
median_household_income <- raw_median_income[c(2,3,324)]
colnames(median_household_income) <- c("GEOID", "Census Tract", "Median Household Income")
median_household_income$GEOID = as.character(median_household_income$GEOID)

#import census tract shapefile and merge median income
census_tract_2020 <- st_read("C:/Users/17166/OneDrive - University at Buffalo/Desktop/Fall Semester 2022/GEO 511/Final Project/2020_NY_census_tract") %>%
  filter(COUNTYFP == "029")

median_income_shape <- census_tract_2020 %>% left_join(median_household_income, by = c("GEOID" = "GEOID"))
median_income_shape$INTPTLATs = as.numeric(median_income_shape$INTPTLAT)
median_income_shape$INTPTLON = as.numeric(median_income_shape$INTPTLON)
#median_income_shape$`Median Household Income` = as.integer(median_income_shape$`Median Household Income`)
median_income_shape$`Median Household Income`=as.numeric(levels(median_income_shape$`Median Household Income`))[median_income_shape$`Median Household Income`]

#convert census tracts to centroids

nc <- median_income_shape %>% 
  st_transform(2262)
nc$`Median Household Income` = as.numeric(nc$`Median Household Income`)
sp_cent <- gCentroid(as(nc, "Spatial"), byid = TRUE)

sf_cent <- st_centroid(nc) 

#Buffalo Supermarkets

Buffalo_supermarkets_csv <- st_read("C:/Users/17166/OneDrive - University at Buffalo/Desktop/Fall Semester 2022/GEO 511/Final Project/Buffalo_Supermarkets/Buffalo_Supermarkets.csv")
buffalo_supermarkets <- geocode(Buffalo_supermarkets_csv$Address, output = c("latlon", "latlona", "more", "all"), source = c("google", "dsk"))

#Buffalo Boundary
Buffalo_border <- st_read("C:/Users/17166/OneDrive - University at Buffalo/Desktop/Fall Semester 2022/GEO 511/Final Project/Buff_border_shape")
Buffalo_sp <- as_Spatial(Buffalo_border)
Buffalo_bbox <- Buffalo_sp@bbox

# Download the basemap
basemap <- get_stamenmap(
  bbox = Buffalo_bbox,
  zoom = 13,
  maptype = "toner-lite")

#Median Income Plot
median_income_plot <- ggplot(census_tract_2020) + 
  geom_sf(data = nc, fill = 'white') + 
  geom_sf(data = sp_cent %>% st_as_sf, color = 'blue') + 
  geom_sf(data = sf_cent, color = 'red')+
  coord_sf(ylim=Buffalo_bbox[c(2,4)], xlim=Buffalo_bbox[c(1,3)]) +
  scale_fill_distiller(palette="YlOrRd", trans="log", direction=-1)


ggmap(basemap) + 
  geom_point(data = nc, aes(x = INTPTLON, y = INTPTLAT, color = "Median Household Income"), 
             size = .025, alpha = 0.7) +
  scale_color_gradient(low = "light green", high = "dark green")

