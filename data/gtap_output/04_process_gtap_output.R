library(tidyverse)

# Get the folder this script is in
script_dir <- dirname(rstudioapi::getSourceEditorContext()$path)

# Build a path relative to the script
file_path <- file.path(script_dir, "202505_Plants_People_v2.csv")

gtapruns <- read.csv(file_path)

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

script_dir <- dirname(rstudioapi::getSourceEditorContext()$path)
file_path  <- file.path(script_dir, "a.png")
ggsave(file_path, plot = a, width = 7, height = 5, dpi = 300)

labor=labor%>%
  mutate(loss_frac=Welfare_in_M_USD/Initial_Income_in_M_USD)

b=ggplot(labor,aes(x=Degrees,y=loss_frac,col=GCM))+geom_point()+theme_bw()+
  labs(x="Degrees Warming (Above Pre-Industrial)",y="Welfare Loss (Fraction Initial Income")

script_dir <- dirname(rstudioapi::getSourceEditorContext()$path)
file_path  <- file.path(script_dir, "b.png")
ggsave(file_path, plot = b, width = 7, height = 5, dpi = 300)
