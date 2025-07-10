#install.packages("xgboost")
#install.packages("SHAPforxgboost")

library(phyloseq)
ps_filtered <- tax_glom(WLO18S.clr, taxrank = "Genus",NArm = FALSE)

# Transpose OTU table to samples x ASVs
asv_counts <- as.data.frame(t(otu_table(ps_filtered)))
asv_counts$SampleID <- rownames(asv_counts)

# Extract metadata
meta <- data.frame(sample_data(ps_filtered), check.names = FALSE)
meta$SampleID <- rownames(meta)


# Merge ASV counts with metadata
df <- base::merge(asv_counts, meta, by = "SampleID")

# Create binary redox label (0 = oxic, 1 = anoxic)
df$Redox <- ifelse(df$Activity == "High", 1, 0)

# Create feature matrix (X) and target vector (y)
X <- df[, grepl("^ASV", colnames(df))]  # all ASV columns
y <- df$Redox


library(xgboost)
library(Matrix)

X_mat <- as(as.matrix(X), "dgCMatrix")
dtrain <- xgb.DMatrix(data = X_mat, label = y)


params <- list(
  booster = "gbtree",
  objective = "binary:logistic",
  eval_metric = "logloss",
  eta = 0.1,
  max_depth = 6,
  subsample = 0.8,
  colsample_bytree = 0.8,
  scale_pos_weight = length(y[y == 0]) / length(y[y == 1])  # handle imbalance
)

# Train model
xgb_model <- xgb.train(
  params = params,
  data = dtrain,
  nrounds = 100,
  verbose = 1
)


library(SHAPforxgboost)
shap_result <- shap.values(xgb_model = xgb_model, X_train = as.matrix(X))
shap_long <- shap.prep(shap_contrib = shap_result$shap_score, X_train = as.matrix(X))



top20shap <- shap.plot.summary.wrap2(shap_score = shap_result$shap_score, X = X, top_n = 10)
top20shap


#Rename ASVID with Genus Name
tax <- as.data.frame(tax_table(ps_filtered))
tax$ASV_ID <- rownames(tax)

top_asvs <- c("ASV96", "ASV175", "ASV172", "ASV20", "ASV47", "ASV40", "ASV3",
              "ASV239", "ASV594", "ASV834")
top_taxa <- tax[rownames(tax) %in% top_asvs, ]
library(tidyr)
library(dplyr)

top_taxa <- top_taxa %>%
  unite("GenusID", ASV_ID, Genus, sep = " ", remove = FALSE)
top_taxa$GenusID


top20shap <- top20shap +
  scale_x_discrete(
    labels = c("ASV96"= "Dinobryon", 
               "ASV175"= "Eustigmatophyceae", 
               "ASV172"= "Paramonas", 
               "ASV20"= "Monodus", 
               "ASV47"="Phaenocora", 
               "ASV40"="Chrysosphaerella", 
               "ASV3"="Pirsonia",
               "ASV239"="Spizellomycetales", 
               "ASV594"="Navicula", 
               "ASV834"= "Lemmermannia"
    )
  )
top20shap