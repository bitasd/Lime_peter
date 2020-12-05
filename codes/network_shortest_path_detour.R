library(ggplot2)
library(dplyr)
library(egg)
library(tidyr)

############################ Detour Factor distribution ################################### 
## reading dist ratio for trips with no loops :trip distance> 400 (m) and is not more than triple that straight line OD distance.
cr_00_140_non_loop <- read.csv(file = 'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\all_aa.csv')
# cr_141_320_non_loop <- read.csv(file = 'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\cr_141_320\\cr_141_320_nonloop.csv')
# cr_321_384_non_loop <- read.csv(file = 'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\cr_321_384\\cr_321_384_nonloop.csv')
# cr_384_500_non_loop <- read.csv(file = 'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\cr_384_500\\cr_384_500_nonloop.csv')


cr_00_140_non <- cr_00_140_non_loop[!is.na(cr_00_140_non_loop$safe_ratio) & cr_00_140_non_loop$safe_ratio >0.98 & cr_00_140_non_loop$safe_ratio < 1000 ,]
# 
# non_loop_lst <- list()
# ### rbind dataframes
# non_loop_lst <- list(data.frame(lts_len_cr_00_140), data.frame(lts_len_cr_141_320), data.frame(lts_len_cr_321_384), data.frame(lts_len_cr_384_500))
# cr_00_500_non_loop <- do.call(rbind, non_loop_lst )
# 
# 
# # write.csv(cr_00_500_non_loop, 'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\cr_00_500_non_loop.csv')
# ### Plotting
# temp <- lts_len_cr_00_500 %>% filter (! dist_ratio %in% c(-999999,'infii')) %>%
#   filter( dist_ratio>0.98 ) %>%
#   filter(dist_ratio <10000)
# 
# 
# cr_00_500_non_loop <- cr_00_500_non_loop %>% filter (! dist_ratio %in% c(-999999,'infii')) %>%
#   filter( dist_ratio>0.98 ) %>%
#   filter(dist_ratio <10000)
# 
# cr_00_500_non_loop$dist_ratio <- as.numeric(as.character(cr_00_500_non_loop$dist_ratio))
##
p1 <- ggplot(cr_00_140_non , aes(x=safe_ratio)) + 
  geom_histogram(aes(y=stat(count)/sum(stat(count))),binwidth=0.01) + 
  scale_color_grey() +
   theme_classic() +
  labs(title="",x="", y = "") +
  coord_cartesian(xlim=c(0.9,3), ylim = c(0,0.3))

p1

quantile(cr_00_140_non$dist_ratio)
# 0%         25%         50%         75%                100% 
#  0.983004  1.006972   1.097038    1.385737       51242.990654 


mean(cr_321_384_non_loop$dist_ratio)
# 1.274781

##################################################################### get the values
df_p_breaks <- seq(.98,4.99, by=0.01)

 
l_df_p <- list()
i <- 0
while(i<302) {
  new_element <- (nrow(cr_00_500_non_loop  %>% filter(dist_ratio > (i+98)/100 & dist_ratio <= (i+99)/100)))/nrow(cr_00_500_non_loop)
  l_df_p[[i+1]] <- new_element
  i <- i + 1
}

l_df_p_table <- unlist(l_df_p)

## DataFrame
l_df_p_dataframe <- data.frame(df_p_breaks, l_df_p_table)
write.csv(outdf,'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\df_ou.csv')

################################# Cumulative Plot

count_breks <- function(cu, cr_){return (nrow(cr_[ cr_$safe_ratio >= cu & cr_$safe_ratio < cu+0.01, ]))}

df_breaks <- seq(0.98,4.99, by=0.01)
br_dataframe <- data.frame(df_breaks)
br_dataframe$trpcounts <- lapply(br_dataframe$df_breaks, count_breks, cr_=cr_00_140_non)
outdf <- rbind(df_breaks, br_dataframe$trpcounts)
write.csv(outdf,'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\df_ou.csv')




# 
# l_df <- list()
# i <- 0
# while(i<301) {
#   new_element <- (nrow(cr_00_500_non_loop  %>% filter(dist_ratio> (i+98)/100 & dist_ratio <= (i+99)/100)))/nrow(cr_00_500_non_loop)
#   l_df[[i+1]] <- new_element
#   i <- i + 1
# }
# 
# l_df_table <- unlist(l_df)
# 
# ## DataFrame
# l_df_dataframe <- data.frame(df_breaks, l_df_table)
# write.csv(l_df_dataframe,'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\cumulative_df.csv')
# 
# p = ggplot() + 
#   geom_line(data = l_df_dataframe, aes(x = df_breaks, y = l_df_table), color = "blue") +
#   xlab('') +
#   ylab('') +
#   theme_bw() + theme(panel.border = element_blank(), panel.grid.major = element_line(),
#                      panel.grid.minor = element_blank(), axis.line = element_line(colour = "black"))
# 
# 
# p <- p + expand_limits(x = 1, y = 0) + scale_x_continuous(expand = c(0, 0)) + scale_y_continuous(expand = c(0, 0)) 
# 
# 
# print(p)



############################ task 4: LTS distribution ################################### 

lts_len_cr_00_140 <- read.csv(file = 'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\cr_00_140\\lts_len_cr_00_140.csv')
lts_len_cr_141_320 <- read.csv(file = 'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\cr_141_320\\lts_len_cr_141_320.csv')
lts_len_cr_321_384 <- read.csv(file = 'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\cr_321_384\\lts_len_cr_321_384.csv')
lts_len_cr_384_500 <- read.csv(file = 'C:\\Users\\bitas\\folders\\Research\\lime\\peter\\data\\detour\\cr_384_500\\lts_len_cr_384_500.csv')

foo <- list()
### rbind dataframes
foo <- list(data.frame(lts_len_cr_00_140), data.frame(lts_len_cr_141_320), data.frame(lts_len_cr_321_384), data.frame(lts_len_cr_384_500))
lts_len_cr_00_500 <- do.call(rbind, foo )


#View(lts_len_cr_141_320)

lts_len_cr_00_500 <- lts_len_cr_00_500 %>% 
    replace_na(list(len_1 = 0, len_2 = 0, len_3 = 0, len_4 =0, len_11= 0, sh_len_1=0, sh_len_2=0, sh_len_3=0, sh_len_4=0, sh_len_11=0))%>% 
                                mutate(len_1_p = len_1/dist_calc) %>% 
                                mutate(len_2_p = len_2/dist_calc)  %>% 
                                mutate(len_1_11_p = (len_1+len_11)/dist_calc)  %>% 
                                mutate(len_1_2_11_p = (len_1+len_2+ len_11)/dist_calc)  %>% 
                                mutate(len_3_p = len_3/dist_calc) %>% 
                                mutate(len_4_p = len_4/dist_calc) 




lts_len_cr_00_500 <- lts_len_cr_00_500 %>% distinct(trip_id, .keep_all = TRUE)
nrow(lts_len_cr_00_500)
# 109693


## detour factor less than 1.25
lts_len_cr_00_500_125 <- lts_len_cr_00_500 %>% filter(dist_ratio<=1.25)

breaks = seq(0.0, 1.0, by=0.001)
breaks <- unlist(breaks)

## LTS 2 and less
l <- list()
i <- 0
while(i<1001) {
  new_element <- (nrow(lts_len_cr_00_500_125  %>% filter(len_1_2_11_p >= i/1000)))/nrow(lts_len_cr_00_500_125)
  l[[i+1]] <- new_element
  i <- i + 1
}

LTS_2_less <- unlist(l)



## LTS 1 and less
l_1 <- list()
i <- 0
while(i<1001) {
  new_element <- (nrow(lts_len_cr_00_500_125  %>% filter(len_1_11_p >= i/1000)))/nrow(lts_len_cr_00_500_125)
  l_1[[i+1]] <- new_element
  i <- i + 1
}

LTS_1_less <- unlist(l_1)

## DataFrame
lts <- data.frame(breaks, LTS_2_less, LTS_1_less)

p = ggplot() + 
  geom_line(data = lts, aes(x = breaks, y = LTS_2_less), color = "blue") +
  geom_line(data = lts, aes(x = breaks, y = LTS_1_less), color = "chartreuse4") +
  xlab('') +
  ylab('') +
  theme_bw() + theme(panel.border = element_blank(), panel.grid.major = element_line(),
                                   panel.grid.minor = element_blank(), axis.line = element_line(colour = "black"))


p <- p + expand_limits(x = 0, y = 0) + scale_x_continuous(expand = c(0, 0)) + scale_y_continuous(expand = c(0, 0)) 


print(p)

################################# task 3: how many m by LTS ################################### 
## df<=1.25  count: 74,655   mean(dist_calc) = 1775.543 m


# LTS 1
sum(lts_len_cr_00_500_125$len_1)
# 38144257

sum(lts_len_cr_00_500_125$sh_len_1)
# 33191907


# LTS 2
sum(lts_len_cr_00_500_125$len_2)
# 3636329
sum(lts_len_cr_00_500_125$sh_len_2)
# 3267036



# LTS 3
sum(lts_len_cr_00_500_125$len_3)
# 59899591
sum(lts_len_cr_00_500_125$sh_len_3)
# 56445525


# LTS 4
sum(lts_len_cr_00_500_125$len_4)
# 22395246
sum(lts_len_cr_00_500_125$sh_len_4)
# 22846746 

# LTS 11
sum(lts_len_cr_00_500_125$len_11)
# 7938148

sum(lts_len_cr_00_500_125$sh_len_11)
# 7920434

# total m traveled df<= 1.25
sum(lts_len_cr_00_500_125$dist_calc)
# 132553155

sum(lts_len_cr_00_500_125$sh_net_dist_calc)
# 123949671

################################# task 2: By day of week ################################### 
lts_len_cr_00_500 <- lts_len_cr_00_500 %>%
                                        mutate(day = weekdays(as.Date(start_time))) %>%
                                        mutate(hour = strftime(as.POSIXct(start_time), format="%H"))

## typeofday

weekend <- filter(lts_len_cr_00_500, day %in% c("Saturday", "Sunday"))
nrow(weekend)
# 29809

week_peak <- filter(lts_len_cr_00_500, !day %in% c("Saturday", "Sunday") & hour %in% c("16","17","18","07","08","09"))
nrow(week_peak)
# 30861

week_nonpeak <- filter(lts_len_cr_00_500, !day %in% c("Saturday", "Sunday") & !hour %in% c("16","17","18","07","08","09"))
nrow(week_nonpeak)
# 49023
########################################### weekend

## DF <=1.25
weekend_125 <- weekend %>% filter(dist_ratio<=1.25)

wnd_125_len_1 <- sum(weekend_125$len_1)/sum(weekend_125$dist_calc)
wnd_125_len_2 <- sum(weekend_125$len_2)/sum(weekend_125$dist_calc)
wnd_125_len_3 <- sum(weekend_125$len_3)/sum(weekend_125$dist_calc)
wnd_125_len_4 <- sum(weekend_125$len_4)/sum(weekend_125$dist_calc)
wnd_125_len_11 <- sum(weekend_125$len_11)/sum(weekend_125$dist_calc)

wnd_125 <- c(wnd_125_len_1, wnd_125_len_2, wnd_125_len_3, wnd_125_len_4, wnd_125_len_11)
# 0.28740865 0.02965194 0.45234955 0.16934277 0.05746257

## DF >2
weekend_200 <- weekend %>% filter(dist_ratio>2)

wnd_200_len_1 <- sum(weekend_200$len_1)/sum(weekend_200$dist_calc)
wnd_200_len_2 <- sum(weekend_200$len_2)/sum(weekend_200$dist_calc)
wnd_200_len_3 <- sum(weekend_200$len_3)/sum(weekend_200$dist_calc)
wnd_200_len_4 <- sum(weekend_200$len_4)/sum(weekend_200$dist_calc)
wnd_200_len_11 <- sum(weekend_200$len_11)/sum(weekend_200$dist_calc)

wnd_200 <- c(wnd_200_len_1, wnd_200_len_2, wnd_200_len_3, wnd_200_len_4, wnd_200_len_11)
# 0.46574982 0.01325203 0.28860028 0.10042510 0.12976836



########################################### weekday peak


## DF <=1.25
week_peak_125 <- week_peak %>% filter(dist_ratio<=1.25)

wp_125_len_1 <- sum(week_peak_125$len_1)/sum(week_peak_125$dist_calc)
wp_125_len_2 <- sum(week_peak_125$len_2)/sum(week_peak_125$dist_calc)
wp_125_len_3 <- sum(week_peak_125$len_3)/sum(week_peak_125$dist_calc)
wp_125_len_4 <- sum(week_peak_125$len_4)/sum(week_peak_125$dist_calc)
wp_125_len_11 <- sum(week_peak_125$len_11)/sum(week_peak_125$dist_calc)

wp_125 <- c(wp_125_len_1, wp_125_len_2, wp_125_len_3, wp_125_len_4, wp_125_len_11)
# 0.31894325 0.02595834 0.42454237 0.16292671 0.06375045

## DF >2
week_peak_200 <- week_peak %>% filter(dist_ratio> 2)

wp_200_len_1 <- sum(week_peak_200$len_1)/sum(week_peak_200$dist_calc)
wp_200_len_2 <- sum(week_peak_200$len_2)/sum(week_peak_200$dist_calc)
wp_200_len_3 <- sum(week_peak_200$len_3)/sum(week_peak_200$dist_calc)
wp_200_len_4 <- sum(week_peak_200$len_4)/sum(week_peak_200$dist_calc)
wp_200_len_11 <- sum(week_peak_200$len_11)/sum(week_peak_200$dist_calc)

wp_200 <- c(wp_200_len_1, wp_200_len_2, wp_200_len_3, wp_200_len_4, wp_200_len_11)
# 0.47516638 0.01416057 0.27666124 0.09831491 0.13432635



########################################### weekday nonpeak


## DF <=1.25
week_nonpeak_125 <- week_nonpeak %>% filter(dist_ratio<=1.25)

wnp_125_len_1 <- sum(week_nonpeak_125$len_1)/sum(week_nonpeak_125$dist_calc)
wnp_125_len_2 <- sum(week_nonpeak_125$len_2)/sum(week_nonpeak_125$dist_calc)
wnp_125_len_3 <- sum(week_nonpeak_125$len_3)/sum(week_nonpeak_125$dist_calc)
wnp_125_len_4 <- sum(week_nonpeak_125$len_4)/sum(week_nonpeak_125$dist_calc)
wnp_125_len_11 <- sum(week_nonpeak_125$len_11)/sum(week_nonpeak_125$dist_calc)

wnp_125 <- c(wnp_125_len_1, wnp_125_len_2, wnp_125_len_3, wnp_125_len_4, wnp_125_len_11)
# 0.26693432 0.02716256 0.47008148 0.17279647 0.05866183

## DF >2
week_nonpeak_200 <- week_nonpeak %>% filter(dist_ratio> 2)

wnp_200_len_1 <- sum(week_nonpeak_200$len_1)/sum(week_nonpeak_200$dist_calc)
wnp_200_len_2 <- sum(week_nonpeak_200$len_2)/sum(week_nonpeak_200$dist_calc)
wnp_200_len_3 <- sum(week_nonpeak_200$len_3)/sum(week_nonpeak_200$dist_calc)
wnp_200_len_4 <- sum(week_nonpeak_200$len_4)/sum(week_nonpeak_200$dist_calc)
wnp_200_len_11 <- sum(week_nonpeak_200$len_11)/sum(week_nonpeak_200$dist_calc)

wnp_200 <- c(wnp_200_len_1, wnp_200_len_2, wnp_200_len_3, wnp_200_len_4, wnp_200_len_11)
# 0.43358525 0.01684369 0.31172934 0.10694059 0.12885707



lts <- c('1','2','3','4','11')
typeofday_lts <- data.frame(lts, wnd_125, wnd_200, wp_125, wp_200, wnp_125, wnp_200)



















