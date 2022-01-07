# Please change the three lines below according to your requirements

# CRAN repo to use
CRANRepo<-"https://packagemanager.rstudio.com/cran/__linux__/focal/latest/"

# Base Path where additional packages for RStudio integration should be installed 
newlibPAth<-"/tmp/additional-packages"

# RStudio version
rstudiover<-"v2021.09.0+351"

########## Main code ############

# set CRAN repo
r<-options()$repos
r["CRAN"]<-CRANRepo
options(repos=r)


# reset libpath to the bare minimum
.libPaths(paste0(Sys.getenv("R_HOME"),"/library"))

# temporarily install requirements to run this code into ./packages/tmp
tmppath="./packages/tmp"
if (dir.exists("./packages/tmp")) { 
  unlink("./packages/tmp",recursive = TRUE)
  }
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

# URL where the requirements for R packages are being kept
URL<-paste0("https://raw.githubusercontent.com/rstudio/rstudio/",rstudiover,"/src/cpp/session/resources/dependencies/r-packages.json")
jsondata <- jsonlite::fromJSON(URL,simplifyDataFrame = TRUE)

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
}

latestdate <- max(mylist[!is.na(mylist)])

destpath=paste0(newlibPAth,"/",R.version$major,".",substr(R.version$minor,0,1))

# reset libpath to the bare minimum
.libPaths(paste0(Sys.getenv("R_HOME"),"/library"))

if (dir.exists(destpath)) {
  unlink(destpath)
}
dir.create(destpath,recursive=TRUE)

.libPaths(c(paste0(Sys.getenv("R_HOME"),"/library"),destpath))

# Attempt to install packages from snapshot - if snapshot does not exist, increase day by 1 and try again
install_packages <- function(packages,latestdate,destpath){
  
  snapshotrepo<-gsub("latest",format(as.Date(latestdate)+1, format="%Y-%m-%d"),options()$repos["CRAN"])
  
  tryCatch(
    expr = {
      install.packages(packages, repos=snapshotrepo,quiet=FALSE, upgrade="never",lib=destpath)
    },
    error = function(e){
      message('Caught an error!')
      print(e)
    },
    warning = function(w){
      message('Caught an error!')
      print(w)
      install_packages(packages, as.Date(latestdate)+1, destpath)
    },
    finally = {
      message('All done, quitting.')
    }
  )    
}

install_packages(namelist, latestdate, destpath)

# Delete temp path 
unlink("./packages/tmp",recursive = TRUE)

# Finally end with the instructions to add a line to Rprofile.site
cat("\n\nInstallation successfuly ! \n")
cat(paste0("IMPORTANT !!!\nNow please add \".libPaths(", destpath,")\" to ", Sys.getenv("R_HOME"),"/Rprofile.site \n"))