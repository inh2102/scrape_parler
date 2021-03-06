scrape_parler <- function(scrolls=10,user='',password='',cache_path='~') {
user <- Sys.getenv('PARLER_USER')
pass <- Sys.getenv('PARLER_PASS')
if (user==''|pass=='') {
  user <- readline(prompt="Enter username (likely email): ") 
  pass <- readline(prompt="Enter password: ") 
  write.table(paste0('PARLER_USER=',user),file=paste0(cache_path,'/.Renviron'),append=TRUE,col.names=FALSE,row.names=FALSE,quote=FALSE)
  write.table(paste0('PARLER_PASS=',pass),file=paste0(cache_path,'/.Renviron'),append=TRUE,col.names=FALSE,row.names=FALSE,quote=FALSE)
}
# SETUP
remDr <- remoteDriver(
  remoteServerAddr = "localhost",
  port = 4445L,
  browserName = "firefox"
)
remDr$open(silent=TRUE)
cat("Navigating to Parler, please wait...")
remDr$navigate("http://parler.com/")
# LOGIN
cat("\nLogging you in...")
webElem <- remDr$findElement(using = "id", "wc--2--login")
webElem$clickElement()
username <- remDr$findElement(using = "id", value = "mat-input-0")
username$sendKeysToElement(list(user))
password <- remDr$findElement(using = "id", value = "mat-input-1")
password$sendKeysToElement(list(pass))
nextButton <- remDr$findElement(using = "xpath", value = '//*[contains(concat( " ", @class, " " ), concat( " ", "w--100", " " ))]')
nextButton$clickElement()
cat("\nLoading captcha in R viewer...")
Sys.sleep(3)
if (length(remDr$findElements(using='id',value='mat-error-0')!=0)) {
  stop("Incorrect credentials, please start over...")
}
captcha <- remDr$findElement(using = "id", value = "mat-input-2")
remDr$screenshot(TRUE)

# CAPTCHA
code <- readline(prompt="Enter CAPTCHA code displayed (case sensitive): ") 
captcha$sendKeysToElement(list(code))
clickNext <- remDr$findElement(using = "xpath", value ='//*[(@id = "auth-form--actions")]//*[contains(concat( " ", @class, " " ), concat( " ", "w--100", " " ))]')
clickNext$clickElement()
Sys.sleep(2)

if (length(remDr$findElements(using='id',value='mat-error-1')!=0)) {
  stop("Incorrect CAPTCHA, please start over...")
}
if (length(remDr$findElements(using='id',value='header--action-items'))==0) {
# TEXT CODE
text <- readline(prompt="Enter digits texted to you (no spaces); ex. 029570: ")
remDr$sendKeysToActiveElement(list(text[1]))
remDr$sendKeysToActiveElement(list(text[2]))
remDr$sendKeysToActiveElement(list(text[3]))
remDr$sendKeysToActiveElement(list(text[4]))
remDr$sendKeysToActiveElement(list(text[5]))
remDr$sendKeysToActiveElement(list(text[6]))
Sys.sleep(2)
  if (length(remDr$findElements(using='id',value='mat-error-2')!=0)) {
    stop("Incorrect SMS code, please start over...")
  }
}
cat("Grabbing page contents...")
remDr$navigate("http://parler.com/discover")
Sys.sleep(2)
for(i in 1:scrolls){      
  remDr$executeScript(paste("scroll(0,",i*10000,");"))
  Sys.sleep(3)
  cat(paste0('\n[',i," scroll(s) completed...]\n"))
}

page_source <- remDr$getPageSource()

author <- read_html(page_source[[1]]) %>% html_nodes(".pm--author--name") %>%
  html_text() %>% str_extract("(?<=\\s)(.*)(?=\\s)")

username <- read_html(page_source[[1]]) %>% html_nodes(".pm--details-user-name") %>%
  html_text() %>% str_extract("(?<=\\s)(.*)(?=\\s)")
username <- username[username!="@"]
username <- username[!is.na(username)]

pub_date <- read_html(page_source[[1]]) %>% html_nodes(".pm--published-date") %>%
  html_text() %>% str_extract("(?<=\\s)(.*)(?=\\s)")

post <- read_html(page_source[[1]]) %>% html_nodes(".post--body-links--wrapper") %>%
  html_text() %>% str_replace( "[\r\n]" , "") %>% str_replace("Your browser does not support the video tag.","") %>% str_replace("\\\\","") %>%
  str_squish()

df <- tibble(author=author,username=username,pub_date=pub_date,post=post,pull_time=Sys.time())

trending <- read_html(page_source[[1]]) %>% html_nodes(".hashtag--tag") %>%
  html_text()

l <- list(df,trending); names(l) <- c("posts","trending_hashtags")

return(l)
}

packages <- function() {
  packages.used <- as.list(
    c(
      "tidyverse",
      "RSelenium",
      "rvest",
      "usethis")
  )
  check.pkg <- function(x){
    if(!require(x, character.only=T)) install.packages(x, 
                                                       character.only=T,
                                                       dependence=T)
  }
  invisible(lapply(packages.used, check.pkg))
}
