# Read in HQs, zips, and Euclidean distance rankings from our last session.
largest_cities <- read.csv('largest_cities.csv', stringsAsFactors=F)
zips_deduped <- read.csv('zips_deduped.csv', stringsAsFactors=F)
zips_deduped$zip <- sprintf('%05d', zips_deduped$zip)
hqs_to_zips_rank <- read.csv('hqs_to_zips_rank.csv')


# Define some constants for making requests to MapQuest and determining
# when to save and what to request.
library(RCurl)
library(rjson)
library(utils)

MAPQUEST_API_KEY <- 'YOUR KEY HERE'
MAPQUEST_API_URL <- 'http://www.mapquestapi.com/directions/v2/routematrix?key=%s&json=%s'
ZIPS_BETWEEN_SAVE <- 250
HQ_RANK_MIN <- 1  # Min/max distance ranks for time estimates
HQ_RANK_MAX <- 10


# Write out a blank file containing our time estimates.
TIME_CSV_PATH <- 'hqs_to_zips_time.csv'
if (!file.exists(TIME_CSV_PATH)) {    
    # Clear out everything except row and column names.
    empty <- as.data.frame(matrix(nrow=nrow(zips_deduped), ncol=nrow(largest_cities)+1))
    names(empty) <- c('zip', largest_cities$name)
    empty$zip <- zips_deduped$zip
    
    # This represents our current state.
    write.csv(empty, TIME_CSV_PATH, row.names=F)    
}

# Read in our current state in case we are starting over.
hqs_to_zips_time <- read.csv(TIME_CSV_PATH)
hqs_to_zips_time$zip <- sprintf('%05d', hqs_to_zips_time$zip)

# Sanity check: If we have any times = 0, set them to NA so that we re-request them.
hqs_to_zips_time[hqs_to_zips_time <= 0] <- NA


# Now we start requesting travel times from MapQuest.
requests_until_save <- ZIPS_BETWEEN_SAVE
col_count <- ncol(hqs_to_zips_time)

# Randomize the zip code order so we fill in the map uniformly as we get more data.
# This will enable us to check on our data over time and make sure it looks right.
for (zip_idx in sample(1:nrow(zips_deduped))) {    
    z <- zips_deduped$zip[zip_idx]
    z_lat <- zips_deduped$latitude[zip_idx]
    z_lon <- zips_deduped$longitude[zip_idx]
    
    # Find PODs for this zip that are in the rank range.
    which_hqs <- which(
        hqs_to_zips_rank[,zip_idx] >= HQ_RANK_MIN &
        hqs_to_zips_rank[,zip_idx] <= HQ_RANK_MAX
    )
    
    # We're only interested in records that aren't filled in yet.
    na_pods <- is.na(hqs_to_zips_time[zip_idx, which_hqs+1])
    if (length(hqs_to_zips_time[zip_idx,2:col_count][na_pods]) < 1) {
        next
    }
    
    # Request this block of PODs and fill them all in.
    print(sprintf('requesting: zip=%s rank=[%d-%d]', z, HQ_RANK_MIN, HQ_RANK_MAX))
    
    # Construct a comma-delimited string of lat/lons containing the locations of our
    # HQs We will use this for our MapQuest requests below: for each zip code, we
    # make one request for its distance to every HQ in our range.
    hq_locations <- paste(
        sprintf("'%f,%f'", largest_cities$lat[which_hqs], largest_cities$long[which_hqs]),
        collapse = ', '
    )
    
    # TODO: make sure we are requesting from location 1 to 2:n only
    request_json <- URLencode(sprintf(
        "{allToAll: false, locations: ['%f,%f', %s]}",
        z_lat,
        z_lon,
        hq_locations
    ))
    url <- sprintf(MAPQUEST_API_URL, MAPQUEST_API_KEY, request_json)
    result <- fromJSON(getURL(url))
    
    # If we get back 0s, they should be NA. Otherwise they'll mess up our
    # rankings and region drawing later.
    result$time[result$time <= 0] <- NA
    
    hqs_to_zips_time[zip_idx, which_hqs+1] <- result$time[2:length(result$distance)]
    
    # See if we should save our current state.
    requests_until_save <- requests_until_save - 1
    if (requests_until_save < 1) {
        print('saving current state')
        write.csv(hqs_to_zips_time, TIME_CSV_PATH, row.names=F)                
        requests_until_save <- ZIPS_BETWEEN_SAVE
    }
}

# Final save once we are done.
write.csv(hqs_to_zips_time, TIME_CSV_PATH, row.names=F)


hqs_to_zips_time <- read.csv(TIME_CSV_PATH)
hqs_to_zips_time$zip <- sprintf('%05d', hqs_to_zips_time$zip)


# Rank HQs by their distance to each unique zip code location.
hqs_to_zips_rank2 <- matrix(nrow=nrow(largest_cities), ncol=nrow(zips_deduped))
for (i in 1:nrow(zips_deduped)) {
    not_na <- !is.na(hqs_to_zips_time[i,2:ncol(hqs_to_zips_time)])
    hqs_to_zips_rank2[not_na,i] <-
        rank(hqs_to_zips_time[i,2:ncol(hqs_to_zips_time)][not_na], ties.method='first')
}


# Now we draw regions for which Dallas is one of the closest 3 HQs by time.
hq_idx <- which(largest_cities$name == 'Dallas TX')
redundancy_levels <- c(3, 2, 1)
fill_alpha <- c(0.15, 0.30, 0.45)

map('state')
for (i in 1:length(redundancy_levels)) {
    # Find every zip for which this HQ is within n in time rank.
    within_n <- hqs_to_zips_rank2[hq_idx,] <= redundancy_levels[i]
    
    # Convex hull of zip code points.
    hull_order <- chull(
        zips_deduped$longitude[within_n], 
        zips_deduped$latitude[within_n]
    )
    hull_x <- zips_deduped$longitude[within_n][hull_order]
    hull_y <- zips_deduped$latitude[within_n][hull_order]
    polygon(hull_x, hull_y, border='blue', col=rgb(0, 0, 1, fill_alpha[i]))   
}

# The other HQs.
other_hqs = 1:nrow(largest_cities) != hq_idx
points(
    largest_cities$long[other_hqs],
    largest_cities$lat[other_hqs], 
    pch = 21, 
    bg = rgb(0.4, 0.4, 0.4, 0.6),
    col = 'black',
    cex = 1.5
)

# This HQ.
points(
    largest_cities$long[hq_idx],
    largest_cities$lat[hq_idx], 
    pch = 21, 
    bg = rgb(1, 0, 0, .85),
    col = 'black',
    cex = 1.5
)

# Map of regions where every zip is served only by its closest HQ.
map('usa')
for (hq_idx in 1:nrow(largest_cities)) {
    # Find every zip for which this HQ is the closest.
    within_1 <- hqs_to_zips_rank2[hq_idx,] == 1
    within_1[is.na(within_1)] <- F
    
    # Convex hull of zip code points.
    hull_order <- chull(
        zips_deduped$longitude[within_1], 
        zips_deduped$latitude[within_1]
    )
    hull_x <- zips_deduped$longitude[within_1][hull_order]
    hull_y <- zips_deduped$latitude[within_1][hull_order]
    polygon(
        hull_x,
        hull_y,
        border = 'black',
        col = rgb(0, 0, 1, 0.25)
    )
}

# All HQs
points(
    largest_cities$long,
    largest_cities$lat, 
    pch = 21, 
    bg = rgb(1, 0, 0, .75),
    col = 'black',
    cex = 1.5
)