#code for plotting figure 6, sensitivity analyses on differing amts of training data
#make sure to load themeo at bottom

rm(list = ls())
library(ggplot2)
library(plotly)
library(DescTools)
library(dplyr)
library(tidyverse)
library(reshape2)
library(gridExtra)
library(grid)


#set drive
dd <- "/Users/jmoxley/Documents/GitTank/CC_CamTags/data/"

#load sensitivity data frames (generated by the code at the bottom of the script)
df <- NULL
load(file.path(dd, "fmo_sensitivity_sims.RData"))
df <- bind_rows(df, saturation %>% mutate(id = "FMO"))
load(file.path(dd, "pr116_sensitivity_sims.RData"))
df <- bind_rows(df, saturation %>% mutate(id = "PR"))
#melt
mdf <- melt(df, id.vars = c("interval", "id"))
#plot (based on SO sol'n here: https://stackoverflow.com/questions/48835600/building-a-ggproto-geom-extension)

#FIGURE CODE
mdf <- mdf %>% mutate(label = factor(paste(str_extract(variable, "[:digit:]{1,2}"), "hr"), 
                                     levels = paste(seq(1:17), "hr")))
#full scale
ggplot(mdf, aes(x = interval, y = value, group=label, color=label)) + 
  geom_point(color = "light gray", alpha = 0.2) +
  lapply(1:10, # NUMBER OF LOESS
         function(i) {
           geom_smooth(data=mdf[sample(1:nrow(mdf), 
                                       2000),  #NUMBER OF POINTS TO SAMPLE
                                ], se=FALSE, span = .95, size = 0.2, method = "loess")
         }) +
  facet_grid(label~id) + themeo +   guides(color = F) +
  labs(x = "AUC Interval (sec x 10^2)", y = "Accuracy (inferred from error %age") + 
  scale_x_continuous(expand=c(0,0), breaks = c(2500, 5000, 7500, 10000), labels = c(25,50,75,100)) + scale_y_continuous(limits = c(0.5, 1.0), breaks=c(0.5, 0.75, 1.0))


#filtered down to 3x2
ggplot(mdf %>% filter(label %in% c("1 hr","4 hr","7 hr")), aes(x = interval, y = value, group=label, color=label)) + 
  geom_point(color = "light gray", alpha = 0.2) +
  lapply(1:10, # NUMBER OF LOESS
         function(i) {
           df <- mdf %>% filter(label %in% c("1 hr", "4 hr", "7 hr"))
           geom_smooth(data=df[sample(1:nrow(df), 
                                       2000),  #NUMBER OF POINTS TO SAMPLE
                                ], se=FALSE, span = .95, size = 0.2, method = "loess")
         }) +
  facet_grid(label~id) + themeo +   guides(color = F) +
  labs(x = "AUC Interval (sec x 10^2)", y = "Accuracy (inferred from error %age") + 
  scale_x_continuous(expand=c(0,0), breaks = c(2500, 5000, 7500, 10000), labels = c(25,50,75,100)) + scale_y_continuous(limits = c(0.5, 1.0), breaks=c(0.5, 0.75, 1.0))


###
#KVH THEMEO
###
themeo <-theme_classic()+
  theme(strip.background = element_blank(),
        axis.line = element_blank(),
        axis.text.x = element_text(margin = margin( 0.2, unit = "cm")),
        axis.text.y = element_text(margin = margin(c(1, 0.2), unit = "cm")),
        axis.ticks.length=unit(-0.1, "cm"),
        panel.border = element_rect(colour = "black", fill=NA, size=.5),
        legend.title=element_blank(),
        strip.text=element_text(hjust=0) )
