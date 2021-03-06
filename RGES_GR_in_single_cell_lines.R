#compute correlation between RGES and drug IC50s in single cell lines

library(cowplot)


############
#functions
############
######
getsRGES1 = function(RGES,  pert_dose, pert_time ){
  sRGES = RGES
  #if (pert_dose != 10 & pert_time != 24){
  if (pert_time == 24){
    sRGES = RGES + predict(lm_dose_24, data.frame(dose=round(log(pert_dose, 10), 1)))
  }
  if (pert_time == 6){
    sRGES = RGES + predict(lm_dose_6, data.frame(dose=round(log(pert_dose, 10), 1)))
  }
  return (sRGES  )
}

getsRGES2 = function(RGES, pert_dose, pert_time, diff){
  
  sRGES = RGES
  pert_time = ifelse(pert_time < 24, "short", "long")
  pert_dose = ifelse(pert_dose < 10, "low", "high")
  if (pert_time == "short" & pert_dose == "low"){
    sRGES = sRGES + diff[4]
  }
  if (pert_dose ==  "low" & pert_time == "long"){
    sRGES = sRGES + diff[2]
  }
  if (pert_dose ==  "high" & pert_time == "short"){
    sRGES = sRGES + diff[1]
  }
  return(sRGES)
}

#correct by dose and time
getsRGES = function(RGES, pert_dose, pert_time, alpha = 0.1, beta = -0.3){
  
  sRGES = RGES 
  
  #older version
  if (pert_time < 24){
    sRGES = sRGES + alpha
  }
  
  if (pert_dose < 10){
    sRGES = sRGES + beta
  }
  return(sRGES)
}

#find best alpha and beta
find_alpha_beta <- function(){
  alphas = seq(-1, 1, 0.1)
  betas = seq(-1, 1, 0.1)
  all_values = data.frame()
  for (alpha in alphas){
    for (beta in betas){
      lincs_drug_prediction_subset = subset(lincs_drug_prediction, cell_id %in% c(cell_line_selected)) #HT29 MCF7
      lincs_drug_prediction_subset$RGES = sapply(1:nrow(lincs_drug_prediction_subset), function(id){
        getsRGES(lincs_drug_prediction_subset[id,"RGES"], lincs_drug_prediction_subset[id, "pert_dose"], lincs_drug_prediction_subset[id, "pert_time"], alpha, beta)
      })
      lincs_drug_prediction_subset = aggregate(RGES ~ pert_iname, lincs_drug_prediction_subset, mean)
      
      activity_RGES = merge(lincs_drug_prediction_subset, lincs_drug_activity_subset, by="pert_iname")
      
      activity_RGES_summarized = activity_RGES #aggregate(cbind(RGES, standard_value) ~ pert_iname, activity_RGES,  min)
      
      cor = cor(activity_RGES_summarized$RGES, log(activity_RGES_summarized$standard_value, 10), method="spearman")
      all_values = rbind(all_values, data.frame(cor, alpha, beta))
    }
  }
  return(all_values)
}

######################
#MAIN
#####################
###
cancer = "BRCA"
cell_line_selected = "MCF7" #HT29, HEPG2
landmark = 1

#build a inference model according to dose and time
output_path <- paste(cancer, "/all_lincs_score.csv", sep="")
lincs_drug_prediction = read.csv(output_path)

lincs_drug_prediction_subset = subset(lincs_drug_prediction,  pert_dose > 0 & pert_time %in% c(6, 24))
#pairs that share the same drug and cell id
lincs_drug_prediction_pairs = merge(lincs_drug_prediction_subset, lincs_drug_prediction_subset, by=c("pert_iname", "cell_id")) 
#x is the reference
lincs_drug_prediction_pairs = subset(lincs_drug_prediction_pairs, id.x != id.y & pert_time.x == 24 & pert_dose.x == 10, select = c("cmap_score.x", "cmap_score.y", "pert_dose.y", "pert_time.y"))

#difference of RGES to the reference 
lincs_drug_prediction_pairs$cmap_diff = lincs_drug_prediction_pairs$cmap_score.x - lincs_drug_prediction_pairs$cmap_score.y
lincs_drug_prediction_pairs$dose = round(log(lincs_drug_prediction_pairs$pert_dose.y, 10), 1)

#fix time
lincs_drug_prediction_pairs_subset = subset(lincs_drug_prediction_pairs, pert_time.y == 24 )
dose_cmap_diff_24 = tapply(lincs_drug_prediction_pairs_subset$cmap_diff, lincs_drug_prediction_pairs_subset$dose, mean)
dose_cmap_diff_24 = data.frame(dose = as.numeric(names(dose_cmap_diff_24)), cmap_diff= dose_cmap_diff_24)
plot(dose_cmap_diff_24$dose, dose_cmap_diff_24$cmap_diff)
lm_dose_24 = lm(cmap_diff ~ dose, data = dose_cmap_diff_24)
summary(lm_dose_24)

lincs_drug_prediction_pairs_subset = subset(lincs_drug_prediction_pairs, pert_time.y == 6)
dose_cmap_diff_6 = tapply(lincs_drug_prediction_pairs_subset$cmap_diff, lincs_drug_prediction_pairs_subset$dose, mean)
dose_cmap_diff_6 = data.frame(dose = as.numeric(names(dose_cmap_diff_6)), cmap_diff= dose_cmap_diff_6)
lm_dose_6 = lm(cmap_diff ~ dose, data = dose_cmap_diff_6)
plot(dose_cmap_diff_6$dose, dose_cmap_diff_6$cmap_diff)
summary(lm_dose_6)

#estimate difference
lincs_drug_prediction_pairs$dose_bin = ifelse(lincs_drug_prediction_pairs$pert_dose.y < 10, "low", "high")
tapply(lincs_drug_prediction_pairs$cmap_diff, lincs_drug_prediction_pairs$dose_bin, mean)
tapply(lincs_drug_prediction_pairs$cmap_diff, lincs_drug_prediction_pairs$pert_time.y, mean)
diff = tapply(lincs_drug_prediction_pairs$cmap_diff, paste(lincs_drug_prediction_pairs$dose_bin, lincs_drug_prediction_pairs$pert_time.y), mean)

#CMAP score output
#output_path <- paste(cancer, "/lincs_score_", landmark, ".csv", sep="")
output_path <- paste(cancer, "/all_lincs_score.csv", sep="")
lincs_drug_prediction = read.csv(output_path)
lincs_drug_prediction = subset(lincs_drug_prediction,  pert_dose > 0 & pert_time %in% c(6, 24))
lincs_drug_prediction$RGES = lincs_drug_prediction$cmap_score

lincs_drug_prediction_subset = subset(lincs_drug_prediction, !cell_id %in% c(cell_line_selected)) #HT29 MCF7
lincs_drug_prediction_subset = aggregate(cbind(RGES) ~ pert_iname, lincs_drug_prediction_subset, mean)

lincs_drug_activity = read.csv(paste(cancer, "/lincs_drug_activity_confirmed.csv", sep=""), stringsAsFactors=F)
lincs_drug_activity = unique(subset(lincs_drug_activity, select=c("pert_iname", "doc_id", "standard_value", "standard_type", "description",    "organism",		"cell_line")))
if (cell_line_selected == "HT29"){
  cell_line_selected_chembl = "HT-29"
}else if (cell_line_selected == "MCF7"){
  cell_line_selected_chembl = "MCF7"
}else if (cell_line_selected == "HEPG2"){
  cell_line_selected_chembl = "HepG2"
}
lincs_drug_activity_subset = subset(lincs_drug_activity, standard_type == "IC50" & cell_line %in% c(cell_line_selected_chembl)) #HT-29 MCF7 HepG2
lincs_drug_activity_subset = aggregate(standard_value ~ pert_iname , lincs_drug_activity_subset, median)

#data_1_LINCS_Pilot_Phase_Joint_Project.csv
lincs_drug_activity_gr = read.csv(paste(cancer, "/data_1_LINCS_Pilot_Phase_Joint_Project.csv", sep=""), stringsAsFactors = F)
lincs_drug_activity_gr$pert_iname = tolower(lincs_drug_activity_gr$smallMolecule)
lincs_drug_activity_gr$standard_value = as.numeric(lincs_drug_activity_gr$GR50)
#lincs_drug_activity_gr$cellLine %in% c("MCF7") & 
lincs_drug_activity_gr = lincs_drug_activity_gr[lincs_drug_activity_gr$cellLine %in% cell_line_selected_chembl & !is.na(lincs_drug_activity_gr$standard_value) & lincs_drug_activity_gr$standard_value != "Inf",]
lincs_drug_activity_gr = aggregate(standard_value ~ pert_iname, lincs_drug_activity_gr, median)
lincs_drug_activity_gr$standard_value = 10^lincs_drug_activity_gr$standard_value

lincs_drug_activity_subset = lincs_drug_activity_gr
activity_RGES = merge(lincs_drug_prediction_subset, lincs_drug_activity_subset, by="pert_iname")

activity_RGES_summarized = activity_RGES #aggregate(cbind(RGES, standard_value) ~ pert_iname, activity_RGES,  min)
dim(activity_RGES_summarized)

cor_test = cor.test(activity_RGES_summarized$RGES, log(activity_RGES_summarized$standard_value, 10), method="spearman")

lm_cmap_ic50 = lm(RGES ~ log(standard_value, 10), activity_RGES_summarized)
summary(lm_cmap_ic50)
summary(lm_cmap_ic50)$r.squared^0.5
cor_test


pdf(paste( "fig/", cancer, "rges_GR_", cell_line_selected, ".pdf", sep=""))
ggplot(activity_RGES_summarized, aes(RGES, log(activity_RGES_summarized$standard_value, 10)  )) +  theme_bw()  + 
  theme(legend.position ="bottom", axis.text=element_text(size=18), axis.title=element_text(size=18))  +                                                                                              
  stat_smooth(method="lm", se=F, color="black")  + geom_point(size=3) + 
        annotate("text", label = paste(cancer, ",", cell_line_selected, sep=""), 
           x = 0, y = 8.1, size = 6, colour = "black") +
        annotate("text", label = paste("r=", format(summary(lm_cmap_ic50)$r.squared ^ 0.5, digit=2), ", ",  "P=", format(anova(lm_cmap_ic50)$`Pr(>F)`[1], digit=2), sep=""), 
                 x = 0, y = 7.7, size = 6, colour = "black") +
        annotate("text", label = paste("rho=", format(cor_test$estimate, digit=2), ", P=", format(cor_test$p.value, digit=3, scientific=T), sep=""), x = 0, y = 7.3, size = 6, colour = "black") +
        scale_size(range = c(2, 5)) +
        xlab("RGES") + guides(shape=FALSE, size=FALSE) +
        ylab("log10(IC50) nm") + coord_cartesian(xlim = c(-0.5, 0.5), ylim=c(-1, 8)) 
dev.off()


#three methods to summarize RGES
lincs_drug_prediction_subset = subset(lincs_drug_prediction, cell_id %in% c(cell_line_selected)) #HT29 MCF7
lincs_drug_prediction_subset$sRGES = sapply(1:nrow(lincs_drug_prediction_subset), function(id){
  getsRGES(lincs_drug_prediction_subset[id,"RGES"], lincs_drug_prediction_subset[id, "pert_dose"], lincs_drug_prediction_subset[id, "pert_time"])
})
lincs_drug_prediction_subset$sRGES1 = sapply(1:nrow(lincs_drug_prediction_subset), function(id){
  getsRGES1(lincs_drug_prediction_subset[id,"RGES"], lincs_drug_prediction_subset[id, "pert_dose"], lincs_drug_prediction_subset[id, "pert_time"])
})
#by default, use this one
lincs_drug_prediction_subset$sRGES = sapply(1:nrow(lincs_drug_prediction_subset), function(id){
  getsRGES2(lincs_drug_prediction_subset[id,"RGES"], lincs_drug_prediction_subset[id, "pert_dose"], lincs_drug_prediction_subset[id, "pert_time"], diff)
})

lincs_drug_prediction_subset_aggregate = aggregate(sRGES ~ pert_iname, lincs_drug_prediction_subset, mean)

activity_RGES = merge(lincs_drug_prediction_subset_aggregate, lincs_drug_activity_subset, by="pert_iname")

activity_RGES_summarized = aggregate(cbind(sRGES, standard_value) ~ pert_iname, activity_RGES,  mean)

activity_RGES_summarized$activity = "effective"
activity_RGES_summarized$activity[activity_RGES_summarized$standard_value>10000] = "ineffective"
efficacy_test = t.test(activity_RGES_summarized$sRGES[activity_RGES_summarized$activity == "effective"], activity_RGES_summarized$sRGES[activity_RGES_summarized$activity == "ineffective"])

cor_test = cor.test(activity_RGES_summarized$sRGES, log(activity_RGES_summarized$standard_value, 10), method="spearman")
cor_test
lm_cmap_ic50 = lm( log(standard_value, 10) ~ sRGES, activity_RGES_summarized)
summary(lm_cmap_ic50)
summary(lm_cmap_ic50)$r.squared^0.5

pdf(paste( "fig/", cancer, "rges_gr_", cell_line_selected, "_normalized.pdf", sep=""))
lm_plot = ggplot(activity_RGES_summarized, aes(sRGES, log(activity_RGES_summarized$standard_value, 10)  )) +  theme_bw()  + 
  theme(legend.position ="bottom", axis.text=element_text(size=18), axis.title=element_text(size=18))  +                                                                                              
  stat_smooth(method="lm", se=F, color="black")  + geom_point(size=3) + 
  annotate("text", label = paste(cancer, ",", cell_line_selected, sep=""), 
           x = 0, y = 8.1, size = 6, colour = "black") +
  annotate("text", label = paste("r=", format(summary(lm_cmap_ic50)$r.squared ^ 0.5, digit=2), ", ",  "P=", format(anova(lm_cmap_ic50)$`Pr(>F)`[1], digit=2), sep=""), 
           x = 0, y = 7.7, size = 6, colour = "black") +
  annotate("text", label = paste("rho=", format(cor_test$estimate, digit=2), ", P=", format(cor_test$p.value, digit=3, scientific=T), sep=""), x = 0, y = 7.3, size = 6, colour = "black") +
  scale_size(range = c(2, 5)) +
  xlab("RGES") + guides(shape=FALSE, size=FALSE) +
  ylab("log10(IC50) nm") + coord_cartesian(xlim = c(-1, 1), ylim=c(-1, 8)) 

bar_plot =  ggplot(activity_RGES_summarized, aes(activity, sRGES  )) + geom_boxplot() +  coord_flip()

ggdraw() +
  draw_plot(lm_plot, 0, .25, 1, .75) +
  draw_plot(bar_plot, 0, 0, 1, .25) 

dev.off()

