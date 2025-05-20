library(tidyverse)

gtapruns=read.csv("..\\small data\\From GTAP\\202505_Plants_People_v2.csv")

#split into crops and labor damage sectors

crops=gtapruns%>%
  filter(Scenario=="Crops Only")%>%
  select(-c(Initial_Income_in_M_USD,GCM))

labor=gtapruns%>%
  filter(Scenario=="Labor Only (All Sectors)")%>%
  select(-c(Percentile,Valueadded_in_M_USD))

#create % losses for each country, warming level, and uncertainty
crops=crops%>%
  mutate(loss_frac=Welfare_in_M_USD/Valueadded_in_M_USD)

a=ggplot(crops,aes(x=Degrees,y=loss_frac,col=Percentile))+geom_point()+theme_bw()+
  labs(x="Degrees Warming (Above Pre-Industrial)",y="Welfare Loss (Fraction Value Added in Ag)")

labor=labor%>%
  mutate(loss_frac=Welfare_in_M_USD/Initial_Income_in_M_USD)

b=ggplot(labor,aes(x=Degrees,y=loss_frac,col=GCM))+geom_point()+theme_bw()+
  labs(x="Degrees Warming (Above Pre-Industrial)",y="Welfare Loss (Fraction Initial Income")
