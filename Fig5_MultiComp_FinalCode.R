#script to build a final version of figure 5
#Multiple composite figure of predictions on 3-hr, 6-hr, 12-hr of training
#data on 6hr of testing data
#Built Apr 2018
rm(list = ls())
library(ggplot2)
library(plotly)
library(DescTools)
library(dplyr)
library(reshape)
library(gridExtra)
library(grid)
library(forcats)
dd <- "/Users/jmoxley/Documents/GitTank/CC_CamTags/data/"

themeo <-theme_classic()+
  theme(strip.background = element_blank(),
        axis.line = element_blank(),
        axis.text.x = element_text(margin = margin( 0.2, unit = "cm")),
        axis.text.y = element_text(margin = margin(c(1, 0.2), unit = "cm")),
        axis.ticks.length=unit(-0.1, "cm"),
        panel.border = element_rect(colour = "black", fill=NA, size=.5),
        legend.title=element_blank(),
        strip.text=element_text(hjust=0) )

#get data
fmo <- read.csv(file.path(dd, "FinMountOrigChks_ODBA_test_obs_pred_1_17_hours.csv"), header = T) %>% 
  select(time.sec, depth, observed = ODBA.obs, ODBA.pred.1hr, ODBA.pred.3hr, ODBA.pred.12hr) %>% 
  filter(!is.na(time.sec))
pr <- read.csv(file.path(dd, "PR161108_ODBA_test_obs_pred_1_18_hours.csv"), header = T) %>% 
  select(time.sec, depth, observed = ODBA.obs, ODBA.pred.1hr, ODBA.pred.3hr, ODBA.pred.12hr) %>% 
  filter(!is.na(time.sec))

#calc time-integrated accuracy
modeled <- fmo
saturation = NULL
#window_max <- 10000 # in seconds
window_max <- 5400 #just over 1.5hr
sims <- 500   # Number of sims
low_win <- seq(from = 2, to = window_max,length.out = 60 )

for(j in 4:ncol(modeled)){
  metric_df_sim <- NULL
  for(x in 1:sims){
    metric_df <- NULL
    x <- NULL
    y_obs <- NULL
    y_pred <- NULL
    for(i in 1:length(low_win)){
      
      # random number selection from which to start window grab
      #rand_num <- sample(1:15000,1)
      #more uniform sampler of entire dataset
      success <- FALSE
      while(!success){    #sample until idx + window is within data bounds
        m <- sample(1:nrow(modeled), 1)
        success <- (m + low_win[i]) <= nrow(modeled)
      }
      rand_num <- m
      print(rand_num)
      
      # acquire vectors describing that window based on indexed window size
      # and starting point random-uniform drawing
      x <- modeled$time.sec[rand_num:(rand_num+low_win[i])]
      y_obs  <- modeled$observed[rand_num:(rand_num+low_win[i])]
      y_pred <- modeled[rand_num:(rand_num+low_win[i]), j]
      
      # calculate area under the curve for actual and observed of the selected window
      AUCobs  <- AUC(x,y_obs)
      AUCpred <- AUC(x,y_pred)
      
      # two evaluation metrics, metric 1 appears sensitive to the magnitude of the AUC
      metric1 <- 1- ( abs( AUCobs - AUCpred )/ low_win[i] )
      metric2 <- ifelse(AUCobs > AUCpred, AUCpred/AUCobs, AUCobs/AUCpred)
      metric3 <- 1 - abs( AUCobs - AUCpred )/ AUCobs
      
      # Build dataframe for one simulation
      # DF: 1 - window size, 2 - metric1 , 3 - metric2
      metric_df$window[i]  <- low_win[i]
      metric_df$metric1[i] <- metric1
      metric_df$metric2[i] <- metric2
      metric_df$metric3[i] <- metric3
    }  
    
    # Repeat X times and row bind the simulations
    metric_df <- as.data.frame(metric_df)
    metric_df_sim <- rbind(metric_df,metric_df_sim)
    print(x) 
  }
  #store results
  if(j==4)  {saturation <- data.frame(interval = metric_df_sim[,1])}   #add windows
  saturation <- bind_cols(saturation, metric_df_sim %>% select(metric3))
  colnames(saturation)[j-2] = colnames(modeled)[j]    
}
#save dataaaa
# fmo.saturation <- mutate(saturation, shark = "Shark 2")
# save(fmo.saturation, file = file.path(dd, "fmo_saturate3.6.12.RData"))
# pr.saturation <- mutate(saturation, shark = "Shark 1")
# save(pr.saturation, file = file.path(dd, "pr.saturation3.6.12.RData"))


##plotting
mdf <- bind_rows(fmo.saturation, pr.saturation) %>% 
  gather(training, accuracy, -interval, -shark) %>% 
  mutate(shark = factor(shark), 
         trainhrs = factor(str_split(training, "\\.", simplify = T)[,3])) 

set.seed(69)
ggplot(data = mdf %>% group_by(shark, trainhrs, interval), 
       aes(x = interval, y = accuracy, group=trainhrs, color=shark)) + 
  geom_point(data = mdf %>% group_by(shark, trainhrs, interval) %>% sample_n(100),
             color = "light gray", alpha = 0.2) +
  lapply(1:50, # NUMBER OF LOESS
         function(i) {
           # geom_smooth(data=mdf[sample(1:nrow(mdf), 
           #                             2000),  #NUMBER OF POINTS TO SAMPLE
           #                      ], se=FALSE, span = .95, size = 0.2, method = "loess") 
           geom_smooth(data=(mdf %>% group_by(shark, trainhrs, interval) %>% sample_n(5)),  #NUMBER OF POINTS TO SAMPLE
                       aes(x = interval, y = accuracy), se=FALSE, span = .90, size = 0.2, method = "loess")
           # geom_smooth(data=(mdf %>% group_by(variable) %>% sample_n(250)),  #NUMBER OF POINTS TO SAMPLE
           #             se=FALSE, span = .95, size = 0.2, method = "loess")
         }) +
  # geom_line(data = mdf %>% group_by(variable, interval) %>% 
  #             summarize(sd = sd(value)), aes(x = interval, y = 1-sd), color = 'black')+
  facet_grid(fct_shift(trainhrs, n = 1L)~shark) +
  themeo + guides(color = F) +
  scale_x_continuous(expand=c(0,0), limits = c(0, window_max), breaks = seq(600, window_max, length.out = 5), labels = c("10","30","50","70","90")) +
  scale_y_continuous(limits = c(0.5, 1.0), breaks=seq(0.5,1.0, length.out=5)) + 
  labs(x = "Sampling interval (in mins)", y = "Predictive accuracy (as inferred from AUC)")
