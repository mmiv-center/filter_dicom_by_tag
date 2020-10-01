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

# test if we can randomize the column in the data frame to get different answers
#df = df[,sample(seq(1,dim(df)[2]))]

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

# add some visualization
# library(rattle) # does not exist on 3.4.4
library(rpart.plot)
svg(paste(args[2], ".svg", sep=""))
# fancyRpartPlot(fit, caption = "Decision Tree Model")
rpart.plot( fit.pruned , extra = 104, box.palette = "GnBu", branch.lty = 3, shadow.col = "gray", nn = TRUE, roundint = FALSE)
dev.off()

pred <- predict(fit.pruned, df[!sub,], type = "class")
idx=row.names(df[!sub,])
erg = data.frame(class=array(pred), study=df[idx,"study"], series=df[idx,"series"])

fileConn<-file(args[2])
tab = fromJSON(toJSON(erg))
tab$splits = names(fit.pruned$variable.importance)
tab$splits_weight = as.character(fit.pruned$variable.importance)
tab$cp_choose = cp_choose
# compute the error rate as well
confusion.matrix = table(predict(fit.pruned, type="class"), df[sub,]$class)
tab$error_train_confusion_matrix = confusion.matrix
tab$accuracy_percent = 100 * sum(diag(confusion.matrix)) / sum(confusion.matrix)
tab$cptable = toString(fit$cptable)
library(RColorBrewer)
library(htmlTable)
tab$rules = htmlTable(rpart.rules(fit.pruned, cover = TRUE))
tab$formula = f
writeLines(toJSON(tab), fileConn)
close(fileConn)
