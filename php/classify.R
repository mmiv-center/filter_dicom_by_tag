# run a small R model on the input data
library(rjson)
library(rpart)

args = commandArgs(trailingOnly=TRUE)
if (length(args)!=2) {
   print(paste("We need two arguments"))
   exit(1);
}
data <- fromJSON(file=args[1]);

df = data.frame(class=as.character(1), train=TRUE, study=as.character(1), series=as.character(1), stringsAsFactors=FALSE)
t='train'
for (i in seq(1, length(data['train'][[1]]))) {
  cl = data['train'][[1]][[i]]$class
  st = data['train'][[1]][[i]]$study
  se = data['train'][[1]][[i]]$series
  dd = data['train'][[1]][[i]]$data
  groups = names(dd)
  for (j in seq(1, length(groups))) {
    tags = names(dd[[groups[[j]]]])
    for ( k in seq(1, length(tags))) {
      tt = paste(paste("g",groups[[j]],sep=""), tags[[k]], sep=".")
      if (! tt %in% names(df)) {
        df[,tt] <- NA
      }
      df[i,c("class","train","study","series",tt)] = c(cl, t, st, se, dd[[groups[[j]]]][[tags[[k]]]])
    }
  }
}
t='predict'
le=dim(df)[1]
for (i in seq(1, length(data['predict'][[1]]))) {
  cl = NA
  st = data['predict'][[1]][[i]]$study
  se = data['predict'][[1]][[i]]$series
  dd = data['predict'][[1]][[i]]$data
  groups = names(dd)
  for (j in seq(1, length(groups))) {
    tags = names(dd[[groups[[j]]]])
    for ( k in seq(1, length(tags))) {
      #print(paste(groups[[j]], tags[[k]]))
      tt = paste(paste("g",groups[[j]],sep=""), tags[[k]], sep=".")
      if (! tt %in% names(df)) {
        df[,tt] <- NA
      }
      df[le+i,c("class","train","study","series",tt)] = c(cl, t, st, se, dd[[groups[[j]]]][[tags[[k]]]])
    }
  }
}
## remove the first row again
##df = df[-1,]
df$g0008.0050 <- NULL
df$g0010.0010 <- NULL
df$g0010.0020 <- NULL
df$g0020.0010 <- NULL
for (i in seq(1, length(names(df)))) {
   a = df[[names(df)[[i]]]]
   if (sum(!is.na(as.numeric(a[!is.na(a)]))) == length(a[!is.na(a)])) {
      df[[ names(df)[[i]] ]] = as.numeric(df[[names(df)[[i]]]])
      warning(paste("Found a numeric vector in ", names(df)[[i]]), immediate=TRUE)
   } else {
      df[[names(df)[[i]]]] = as.factor(df[[names(df)[[i]]]])
   }
}


idx = grep("0([0-9]+)[YM]", df$g0010.1010, value=FALSE)
if (length(idx) > 0) {
  # this does not work because we cannot convert the column from factor to numeric this way
  df$g0010.1010 <- as.numeric(as.integer(sub("0([0-9]+)Y", "\\1", df$g0010.1010)))
}

idx = grep("([0-9]+) %", df$g0040.0310, value=FALSE)
if (length(idx) > 0) {
   df$g0040.0310 <- as.numeric(as.integer(sub("([0-9]+) %", "\\1", df$g0040.0310)))
}

idx = grep("([0-9]+)", df$g0020.1209, value=FALSE)
if (length(idx) > 0) {
   df$g0020.1209 <- as.numeric(as.integer(sub("([0-9]+)", "\\1", df$g0020.1209)))
}

# g0028.0030 for pixel spacing    # c = strsplit(a, "\\\\");
if ( !is.na(match("g0028.0030", names(df))) ) {
   df$g0028.0030row <- as.numeric(as.character(sub("(.*)\\\\(.*)", "\\1", df$g0028.0030)))
   df$g0028.0030col <- as.numeric(as.character(sub("(.*)\\\\(.*)", "\\2", df$g0028.0030)))
}

# test if we can randomize the column in the data frame to get different answers
#df = df[,sample(seq(1,dim(df)[2]))]

# If we create more than one model we can identify data objects where the models disagree in their
# prediction. Those would be good candidates for active learning based "query by commitee". If the 
# user would label those we can create a better collection of models.
disagree_list <- data.frame(study=as.character(), series=as.character())
model_before <- NULL

# we want to compute more than 1 model, in this case we can create a model first and 
# remove its components from the data frame before computing another model
censor <- c()
stopIfBadModel <- FALSE
bestAccuracy <- NULL
countModels <- 0
repeat {
  # lets remove the variables from the data frame that are censored in this repeat run
  df <- df[,!(names(df) %in% censor)]

  sub = (df$train == "train")

  tr = df[sub,]
  pr = df[!sub,]
  rem = c()
  for (i in seq(1, length(names(tr)))) {
    co = names(tr)[i]
    if (class(df[[co]]) == "factor") {
      pr[[co]] <- factor(pr[[co]], levels = levels(tr[[co]]))
      if (length(levels(tr[[co]])) < 2 & co != "class" & co != "series" & co != "study" & co != "train") {
        rem = c(rem, co)
      }
    }
  }
  df[!sub,] = pr
  df = df[,!names(df) %in% rem]
  #print(paste("left over variables are: ", length(names(df))))

  v = names(df)
  v = v[-which(names(df) %in% c("class","train","study","series"))]
  f = paste("class ~", paste(v, collapse=" + "))
  #
  # rpart can do its own boostrap based pruning, here we take control and prune by 1-err
  #
  fit  <- rpart(formula(f), data=df[sub,], control=list(cp=0, minsplit=1, minbucket=1), method="class")


  cp_choose <- fit$cptable[,1][which.min(fit$cptable[,4])]
  print(paste("Prune value is (1SE rule): ", cp_choose, sep=""))
  fit.pruned <- prune.rpart(fit, cp_choose)

  # variables used in the generation of the tree
  treevars <- levels(fit$frame$var)[!(levels(fit$frame$var) %in% "<leaf>")]

  pred <- predict(fit.pruned, df[!sub,], type = "class")
  idx=row.names(df[!sub,])
  erg = data.frame(class=array(pred), study=df[idx,"study"], series=df[idx,"series"])
  # here we know the predictions, we should compare with the once we have already and 
  # find entries where the class is different (we don't care about the class).
  if (is.null(model_before))
    model_before <- erg
  disagree_list <- merge(disagree_list, (anti_join(model_before, erg))[,c("study","series")], by=c("study", "series"), all=TRUE)

  confusion.matrix = table(predict(fit.pruned, type="class"), df[sub,]$class)
  accuracy_percent = 100 * sum(diag(confusion.matrix)) / sum(confusion.matrix)
  # ok, we are still in the repeat loop, we want to get out if we have a worst model
  if (is.null(bestAccuracy)) {
    bestAccuracy <- accuracy_percent
  }
  if (bestAccuracy > accuracy_percent || countModels > 10) {
    # ignore if the model gets worse -- but we need to ignore before we save anything...
    break;
  }
  # now add the current list of variables to the banned list
  censor <- c(censor, treevars)

  #
  # save our results
  #

  # we should store our model in the output folder for later predictions
  saveRDS(fit.pruned, paste(args[2], sprintf("_model_%04d", countModels), ".RDS", sep=""))

  # add some visualization
  # library(rattle) # does not exist on 3.4.4
  library(rpart.plot)
  svg(paste(args[2], sprintf("_%04d", countModels), ".svg", sep=""))
  # fancyRpartPlot(fit, caption = "Decision Tree Model")
  rpart.plot( fit.pruned , extra = 104, box.palette = "GnBu", branch.lty = 3, shadow.col = "gray", nn = TRUE, roundint = FALSE)
  dev.off()

  fileConn<-file(paste(args[2], sprintf("_%04d", countModels), sep=""))
  tab = fromJSON(toJSON(erg))
  tab$splits = names(fit.pruned$variable.importance)
  tab$splits_weight = as.character(fit.pruned$variable.importance)
  tab$cp_choose = cp_choose
  # compute the error rate as well
  tab$error_train_confusion_matrix = confusion.matrix
  tab$accuracy_percent = 100 * sum(diag(confusion.matrix)) / sum(confusion.matrix)
  tab$cptable = toString(fit$cptable)
  tab$treevars = treevars
  library(RColorBrewer)
  library(htmlTable)
  tab$rules = htmlTable(rpart.rules(fit.pruned, cover = TRUE))
  tab$formula = f
  tab$disagree_list = disagree_list
  writeLines(toJSON(tab), fileConn)
  close(fileConn)

  countModels = countModels + 1
}
