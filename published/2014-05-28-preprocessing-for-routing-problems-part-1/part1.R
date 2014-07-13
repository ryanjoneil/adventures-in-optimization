# Code for the adventures in optimization post:
# preprocessing for routing problems: part 1

library(datasets)
library(zipcode)
data(zipcode)

# Alexandria, VA is not in Normandy, France.
zipcode[zipcode$zip=='22350', c('latitude', 'longitude')] <- c(38.863930, -77.055547)

# New York City, NY is not in Kyrgyzstan.
zipcode$longitude[zipcode$zip=='10200'] <- -zipcode$longitude[zipcode$zip=='10200']

# Pare down to zip codes in the continental US.
states_continental <- state.abb[!(state.abb %in% c('AK', 'HI'))]
zips_continental <- subset(zipcode, state %in% states_continental)
zips_deduped <- zips_continental[!duplicated(zips_continental[, c('latitude', 'longitude')]), ]

# Geographic information for top 25 cities in the country.
library(maps)
data(us.cities)
largest_cities <- subset(
    us.cities[order(us.cities$pop, decreasing=T),][1:25,],
    select = c('name', 'lat', 'long')
)

# Plot our corporate headquarters and every unique zip code location.
map('state')
points(zips_deduped$longitude, zips_deduped$latitude, pch=21, col=rgb(0, 0, 1, .5), cex=0.1)
points(largest_cities$long, largest_cities$lat, pch=21, bg=rgb(1, 0, 0, .75), col='black', cex=1.5)

# Euclidean distance from each HQ to each zip code.
library(SpatialTools)
zips_to_hqs_dist <- dist2(
    matrix(c(zips_deduped$longitude, zips_deduped$latitude), ncol=2),
    matrix(c(largest_cities$long, largest_cities$lat), ncol=2)
)

# Rank HQs by their distance to each unique zip code location.
hqs_to_zips_rank <- matrix(nrow=nrow(largest_cities), ncol=nrow(zips_deduped))
for (i in 1:nrow(zips_deduped)) {
    hqs_to_zips_rank[,i] <- rank(zips_to_hqs_dist[i,], ties.method='first')
}

# Now we draw regions for which Dallas is one of the closest 3 HQs.
hq_idx <- which(largest_cities$name == 'Dallas TX')
redundancy_levels <- c(3, 2, 1)
fill_alpha <- c(0.15, 0.30, 0.45)

map('state')
for (i in 1:length(redundancy_levels)) {
    # Find every zip for which this HQ is within n in distance rank.
    within_n <- hqs_to_zips_rank[hq_idx,] <= redundancy_levels[i]
    
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
    within_1 <- hqs_to_zips_rank[hq_idx,] == 1
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

# Write out data for the next script.
write.csv(largest_cities, 'largest_cities.csv')
write.csv(zips_deduped, 'zips_deduped.csv')
write.csv(hqs_to_zips_rank, 'hqs_to_zips_rank.csv', row.names=F)