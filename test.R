# reset libpath to the bare minimum
.libPaths(paste0(Sys.getenv("R_HOME"),"/library"))

# temporarily install requirements for this code into ./packages/tmp
tmppath="./packages/tmp"
dir.create(tmppath, recursive=TRUE)
install.packages(c("RCurl","curl","selectr","tibble", "jsonlite","data.table","rvest","anytime","stringr"),lib = tmppath)

# extend libPath
.libPaths(c(paste0(Sys.getenv("R_HOME"),"/library"),tmppath))

# load libraries
library(jsonlite)
library(selectr)
library(data.table)
library(rvest)
library(anytime)
library(stringr)
library(tibble)
library(curl)
library(RCurl)

getpackagetime <- function(packagename,packageversion) {
  
  url <- paste0("https://cran.r-project.org/src/contrib/Archive/",packagename)
  dat <- setDT(html_table(html_node(read_html(url), "table")))
  df<-dat[, Date := anytime(`Last modified`)][ !is.na(Date), .(Name, Date)]
  df <- data.frame(lapply(df, function(x) { gsub(".tar.gz", "", x)}))
  df <- data.frame(lapply(df, function(x) { gsub(paste0(packagename,"_"), "", x)}))
  retvalue=df[df$Name == packageversion,]$Date
  if (identical(retvalue, character(0))) {
    return(NA)
  } else {
    return(retvalue)
  }
}



#https://raw.githubusercontent.com/rstudio/rstudio/main/src/cpp/session/resources/dependencies/r-packages.json

URL<-"https://raw.githubusercontent.com/rstudio/rstudio/v2021.09.1%2B372/src/cpp/session/resources/dependencies/r-packages.json"
jsondata <- jsonlite::fromJSON(URL,simplifyDataFrame = TRUE)

#+0*seq(1,length(jsondata$packages))
# extend libPath




mylist <- c()
namelist <- c()
for (i in seq(1,length(jsondata$packages))) {
  name=names(jsondata$packages[i])
  version=jsondata$packages[i][[1]]$version
  location=jsondata$packages[i][[1]]$location
  source=jsondata$packages[i][[1]]$source
  cat (i, name, version, "\n")
  mydate<-format(as.Date(getpackagetime(name,version)))
  mylist <- c(mylist,mydate)
  namelist <- c(namelist, name)
  print(mylist)
}

latestdate <- max(mylist[!is.na(mylist)])

snapshotrepo<-gsub("latest",format(as.Date(latestdate), format="%Y-%m-%d"),options()$repos["CRAN"])

destpath=paste0("./packages/needed/",R.version$major,".",substr(R.version$minor,0,1))

# reset libpath to the bare minimum
.libPaths(paste0(Sys.getenv("R_HOME"),"/library"))

dir.create(destpath,recursive=TRUE)

.libPaths(c(paste0(Sys.getenv("R_HOME"),"/library"),destpath))
install.packages(namelist, repos=snapshotrepo,quiet=FALSE, upgrade="never",lib=destpath)

