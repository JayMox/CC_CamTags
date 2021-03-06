#Saturation curves for NN manuscript
#building a figure for goodness of fits using increasing amounts of training data.  
#go to bottom for aggregation of goodness of fit metrics
rm(list = ls())
library(ggplot2)
library(plotly)
library(DescTools)
library(dplyr)
library(tidyverse)
library(reshape2)
library(gridExtra)
library(grid)

themeo <-theme_classic()+
  theme(strip.background = element_blank(),
        axis.line = element_blank(),
        axis.text.x = element_text(margin = margin( 0.2, unit = "cm")),
        axis.text.y = element_text(margin = margin(c(1, 0.2), unit = "cm")),
        axis.ticks.length=unit(-0.1, "cm"),
        panel.border = element_rect(colour = "black", fill=NA, size=.5),
        legend.title=element_blank(),
        strip.text=element_text(hjust=0) )

#set drive
dd <- "/Users/jhmoxley/Documents/Biologia & Animales/[[GitTank]]/CC_CamTags/data"

#load sensitivity data frames (generated by the code at the bottom of the script)
df <- NULL
load(file.path(dd, "fmo_sensitivity_sims.RData"))
sc <- read.csv(file.path(dd, "fmo_sensitivity_sims.csv"))
df <- bind_rows(df, saturation %>% mutate(id = "FMO"))
load(file.path(dd, "pr116_sensitivity_sims.RData"))
df <- bind_rows(df, saturation %>% mutate(id = "PR"))
#melt
mdf <- melt(df, id.vars = c("interval", "id"))
#plot (based on SO sol'n here: https://stackoverflow.com/questions/48835600/building-a-ggproto-geom-extension)

load(file.path(dd, "pr116_sensitivity_sims.RData"))
data <- melt(saturation, id.vars = "interval")

x  <- seq(1,1000,1)
y1 <- rnorm(n = 1000,mean = (x*2)^1.1+500, sd = 200)
y2 <- rnorm(n = 1000,mean = x*1.3, sd = 287.3)
y3 <- rnorm(n = 1000,mean = (x*1.1)^-5, sd = 100.1)
ddata <- data.frame(x, y1, y2, y3)
ddata <- melt(ddata, id.vars = "x")



ggplot(mdf,aes(x=interval,y=value))+
  geom_point(size = .1)+
  facet_wrap(~variable)

#############
##FIGURE PLOT
mdf <- mdf %>% mutate(label = factor(str_extract(variable, "[:digit:]{1,2}"), 
                                     levels = as.character(seq(1:17))))
ggplot(mdf, aes(x = interval, y = value, group=label, color=label)) + 
  geom_point(color = "light gray", alpha = 0.2) +
  lapply(1:10, # NUMBER OF LOESS
         function(i) {
           geom_smooth(data=mdf[sample(1:nrow(mdf), 
                                        2000),  #NUMBER OF POINTS TO SAMPLE
                                 ], se=FALSE, span = .95, size = 0.2, method = "loess")
         }) +
  facet_grid(variable~id) + themeo +   guides(color = F) +
  scale_x_continuous(expand=c(0,0)) + scale_y_continuous(limits = c(0.5, 1.0), breaks=c(0.5, 0.75, 1.0))


                                          
################
################
#
predict(tp_est, newdata = 
          data.frame(xx = seq(min(data$predictor), max(data$predictor), length.out = 500)))

ggplot(data, aes(x = interval, y = value, group=variable, color=variable)) + 
  geom_point(color = "light gray") +
  lapply(1:10, # NUMBER OF LOESS
         function(i) {
           geom_smooth(data=data[sample(1:nrow(data), 
                                         500),  #NUMBER OF POINTS TO SAMPLE
                                  ], se=FALSE, span = .9, size = 0.2, method = "loess")
         }) 

ggplot(data, aes(x, value, group=variable, color = variable)) + 
  geom_point(color = "light gray") +
  lapply(1:100, # NUMBER OF LOESS
         function(i) {
           geom_smooth(data=data[sample(1:nrow(data), 
                                        70),  #NUMBER OF POINTS TO SAMPLE
                                 ], se=FALSE, span = .9, size = 0.2)
           
         })

  #facet_wrap(~id) + 
  ylim(c(0,1)) + themeo



#################
##See below for aggregation of sensitivity metrics
#################
df <- read_csv(file.path(dd, "FinMountOrigChks_ODBA_test_obs_pred_1_17_hours.csv")) %>% 
  select(-X21) %>% filter(!is.na(depth))  #clip NAs to create a 6 hour test set using increasing amts of trianing data
#df <- df[,1:6]   #minidataset

#Goodness of Fit simulations
window_max <- 10000 # in seconds
low_win <- seq(from = 1, to = window_max,length.out = 50 )
sims <- 100
saturation <- data.frame(interval = rep(low_win, times = sims))

for(j in 4:ncol(df)){
  #subset data of interet
  modeled <- df[,c(1,3,j)]  #time-sec, obsODBA, & predOBA w/ relevant training data
  colnames(modeled) <- c("time.sec", "observed", "predicted")

  #clear storage space
  metric_df_sim <- NULL

  #jackknife
  for(x in 1:sims){
    metric_df <- NULL
    
    for(i in 1:length(low_win)){
      
      # random number selection from which to start window grab
      rand_num <- sample(1:15000,1)
      print(rand_num)
      
      # acquire vectors describing that window based on indexed window size
      # and starting point random-uniform drawing
      x <- modeled$time.sec[rand_num:(rand_num+low_win[i])]
      y_obs  <- modeled$observed[rand_num:(rand_num+low_win[i])]
      y_pred <- modeled$predicted[rand_num:(rand_num+low_win[i])]
      
      # calculate area under the curve for actual and observed of the selected window
      AUCobs  <- DescTools::AUC(x,y_obs)
      AUCpred <- DescTools::AUC(x,y_pred)
      
      # two evaluation metrics, metric 1 appears sensitive to the magnitude of the AUC
      #metric1 <- 1- ( abs( AUCobs - AUCpred )/ low_win[i] )
      #metric2 <- ifelse(AUCobs > AUCpred, AUCpred/AUCobs, AUCobs/AUCpred)
      metric3 <- 1 - abs( AUCobs - AUCpred )/ AUCobs  #error percentage
      
      # Build dataframe for one simulation
      # DF: 1 - window size, 2 - metric1 , 3 - metric2
      metric_df$window[i]  <- low_win[i]
      metric_df$metric3[i] <- metric3
    }  
    
    # Repeat X times and row bind the simulations
    metric_df <- as.data.frame(metric_df)
    metric_df_sim <- rbind(metric_df,metric_df_sim)
    print(x) 
  }
  #store data
  saturation[,j-2] <- metric_df_sim$metric3
  colnames(saturation)[j-2] <- paste(colnames(df[,j]), "-sim", sep="");
  print(paste(j, "IS DONE"))
}
#save(saturation, file = file.path(dd, "fmo_sensitivity_sims.RData"))


#####
##other dataset
#####
#set drive
dd <- "/Users/jmoxley/Documents/GitTank/CC_CamTags/data/"
df <- read_csv(file.path(dd, "PR161108_ODBA_test_obs_pred_1_18_hours.csv")) %>% 
  select(-X21) %>% filter(!is.na(depth))  #clip NAs to create a 6 hour test set using increasing amts of trianing data
#df <- df[,1:6]   #minidataset
#Goodness of Fit simulations
window_max <- 10000 # in seconds
low_win <- seq(from = 1, to = window_max,length.out = 50 )
sims <- 100
saturation = NULL;
saturation <- data.frame(interval = rep(low_win, times = sims))

for(j in 4:ncol(df)){
  #subset data of interet
  modeled <- df[,c(1,3,j)]  #time-sec, obsODBA, & predOBA w/ relevant training data
  colnames(modeled) <- c("time.sec", "observed", "predicted")
  
  #clear storage space
  metric_df_sim <- NULL
  
  #jackknife
  for(x in 1:sims){
    metric_df <- NULL
    
    for(i in 1:length(low_win)){
      
      # random number selection from which to start window grab
      rand_num <- sample(1:15000,1)
      print(rand_num)
      
      # acquire vectors describing that window based on indexed window size
      # and starting point random-uniform drawing
      x <- modeled$time.sec[rand_num:(rand_num+low_win[i])]
      y_obs  <- modeled$observed[rand_num:(rand_num+low_win[i])]
      y_pred <- modeled$predicted[rand_num:(rand_num+low_win[i])]
      
      # calculate area under the curve for actual and observed of the selected window
      AUCobs  <- DescTools::AUC(x,y_obs)
      AUCpred <- DescTools::AUC(x,y_pred)
      
      # two evaluation metrics, metric 1 appears sensitive to the magnitude of the AUC
      #metric1 <- 1- ( abs( AUCobs - AUCpred )/ low_win[i] )
      #metric2 <- ifelse(AUCobs > AUCpred, AUCpred/AUCobs, AUCobs/AUCpred)
      metric3 <- 1 - abs( AUCobs - AUCpred )/ AUCobs  #error percentage
      
      # Build dataframe for one simulation
      # DF: 1 - window size, 2 - metric1 , 3 - metric2
      metric_df$window[i]  <- low_win[i]
      metric_df$metric3[i] <- metric3
    }  
    
    # Repeat X times and row bind the simulations
    metric_df <- as.data.frame(metric_df)
    metric_df_sim <- rbind(metric_df,metric_df_sim)
    print(x) 
  }
  #store data
  saturation[,j-2] <- metric_df_sim$metric3
  colnames(saturation)[j-2] <- paste(colnames(df[,j]), "-sim", sep="");
  print(paste(j, "IS DONE"))
}
#save(saturation, file = file.path(dd, "pr116_sensitivity_sims.RData"))
