library(dplyr)
library(sf)
library(httr)
library(sp)
library(data.table)
library(stringr)
library("rgdal", lib.loc="/usr/local/lib/R/site-library")
library(tidyr)
library(readr)
library(tidyverse)
library(tidycensus)
library(tigris)
library(rjson)




# load data -------------------------------------------------------------------------
# load parcel living units information
uploadpath = "Synthetic_population/Housing_units_distribution/Fairfax/data/working/"
parcel_livunit <- read.csv(paste0(uploadpath,"va059_sdad_parcel_bg_livingunits.csv.xz"))

# load ACS data (demographics infos on age, gender and race) for DC
acs_age <- read.csv("Age/data/distribution/va_trctbg_acs_20092020_age_demographics.csv.xz") %>% filter(region_type=='block group')
acs_gender <- read.csv("Gender/data/distribution/va_trctbg_acs_20092020_gender_demographics.csv.xz") %>% filter(region_type=='block group') %>% filter(!(measure=='total_pop'))
acs_race <- read.csv("Race/data/distribution/va_trctbg_acs_20092020_race_demographics.csv.xz") %>% filter(region_type=='block group') %>% filter(!(measure=='total_pop'))
acs_language <- read.csv("Language/data/distribution/va_trctbg_acs_20092020_language_demographics.csv.xz") %>% filter(region_type=='block group')
acs <- rbind(acs_age,acs_gender,acs_race,acs_language)


# subset the acs data to fairfax ----------------------------------------------------
# get the acs demographics for 2019
fairfax_bg2010 <- block_groups("VA", "059", 2010) %>% select(geoid=GEOID) %>% mutate(geoid=as.numeric(geoid)) 
fairfax_bg2010 <- unique(fairfax_bg2010$geoid)

fairfax_acs2010 <- acs %>%
  filter(year==2019) %>%
  filter(geoid %in% fairfax_bg2010) 

# get the acs demographics for 2020
fairfax_bg2020 <- block_groups("VA", "059", 2020) %>% select(geoid=GEOID) %>% mutate(geoid=as.numeric(geoid))
fairfax_bg2020 <- unique(fairfax_bg2020$geoid)

fairfax_acs2020 <- acs %>%
  filter(year==2020) %>%
  filter(geoid %in% fairfax_bg2020) 



# compute the demographic multiplier -------------------------------------------------
# comments: a block group can have a set of parcels with a total of 0 living units, for those case we can refine the demographics informations. 
#           Those cases are identified with a multiplier equals to NA. we exclude them
temp <- parcel_livunit %>%
  mutate(bg_geo=as.numeric(substr(geoid, 1, 12))) %>%
  group_by(bg_geo) %>%
  mutate(bg_unitcnt=sum(liv_unit, na.rm=T),
         mult=liv_unit/bg_unitcnt) %>%
  rename(parid=geoid) %>%
  filter(!is.na(mult)) %>%
  select(parid,bg_geo,mult)



# compute the demographics at the parcels --------------------------------------------
# note: refine the demographics for block groups with the demographics informations
#       - some block group in parcels doesn't match the acs (2010) but belong to acs (2020), remove them
fairfax_parcel_dmg <- merge(fairfax_acs2010, temp, by.x='geoid', by.y='bg_geo', all.y=T) %>%
  mutate(value=mult*value,
         region_name=paste0('parcel ',parid),
         region_type='parcel') %>%
  filter(!is.na(measure)) %>%
  select(geoid=parid,region_name,region_type,measure,value)


# save the data
savepath = "Synthetic_population/Housing_units_distribution/Fairfax/data/working/"
readr::write_csv(fairfax_parcel_dmg, xzfile(paste0(savepath,"va059_pc_sdad_2019_demographics.csv.xz"), compression = 9))




