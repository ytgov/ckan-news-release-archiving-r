library(tidyverse)
library(fs)
library(readxl)
library(rmarkdown)
library(janitor)
library(rvest)

run_start_time <- now()
paste("Start time:", run_start_time)

news_releases <- read_xlsx("input/yukon.ca-news-releases-published-2018-2021.xlsx")

html_template_start <- read_file("templates/start.html")
html_template_end <- read_file("templates/end.html")

# Today's date in YYYY-MM-DD format:
meta_archived_date <- str_sub(now(), 0L, 10L)

# Testing: limit to a subset of news releases
news_releases <- news_releases |>
  slice_head(n = 5)

# Generate the current year from the date published field
news_releases <- news_releases |> 
  mutate(
    year = str_sub(publish_date, 0L, 4L)
  )

# Add a language-specific author string
# This news release has been archived. For current Government of Yukon news, visit <a href="https://yukon.ca/news">Yukon.ca/news</a>.
news_releases <- news_releases |> 
  mutate(
    author = case_when(
      language == "fr" ~ "Gouvernement du Yukon",
      .default = "Government of Yukon"
    ),
    archive_alert_message_text = case_when(
      language == "fr" ~ 'Ce communiqué de presse a été archivé. Pour les dernières nouvelles, visitez <a href="https://yukon.ca/fr/communiques-de-presse">Yukon.ca/fr/communiques-de-presse</a>.',
      .default = 'This news release has been archived. For current Government of Yukon news, visit <a href="https://yukon.ca/news">Yukon.ca/news</a>.'
    ),
    archived_date = meta_archived_date
  )

# Clean up some poorly-formatted news release numbers
news_releases <- news_releases |> 
  mutate(
    news_release_number = str_replace_all(news_release_number, "#", ""),
  ) |> 
  mutate(
    news_release_number = str_replace_all(news_release_number, "=", "-"),
  )

# Remove " quote characters from descriptions to be on the safe side.
news_releases <- news_releases |> 
  mutate(
    meta_description = str_replace_all(meta_description, '"', ""),
  )

retrieve_individual_news_release <- function(page_url, year, news_release_number, language, title, description, author, publish_date, archived_date, archive_alert_message_text) {
  
  html_output_path <- path("output", language, year, str_c(news_release_number, ".html"))
  
  if(file_exists(html_output_path)) {
    cat(str_c("- Path ", html_output_path, " already exists.\n"))
    return()
  }
  
  # Be gentle to the server between requests!
  Sys.sleep(1)
  
  news_release_html <- read_html(page_url) |> 
    html_element("main")
  
  remove_node_feedback_form <- news_release_html |> 
    html_node("div#block-page-feedback-webform")
  
  remove_node_date_modified <- news_release_html |> 
    html_node("div.node-date-modified")
  
  remove_node_breadcrumbs <- news_release_html |> 
    html_node("div.region-breadcrumb")
  

  
  # Thanks to
  # https://stackoverflow.com/a/50769954/756641
  xml2::xml_remove(remove_node_feedback_form)
  xml2::xml_remove(remove_node_date_modified)
  xml2::xml_remove(remove_node_breadcrumbs)
  
  dir_create(path("output", language, year))
  
  # paste(path("output", language, year, str_c(news_release_number, ".html")))
  
  # paste(news_release_html)
  
  # formatted_html_template_start <- html_template_start |> 
  #   str_replace("%%TITLE%%", title) |> 
  #   str_replace("%%DESCRIPTION%%", description)
  
  formatted_html_template_start <- html_template_start |> 
    str_glue(
      title = title, 
      language = language, 
      description = description, 
      author = author, 
      date = publish_date, 
      archived_date = archived_date,
      news_release_number = news_release_number,
      page_url = page_url,
      archive_alert_message_text = archive_alert_message_text
    )
    
  # Update image paths (still loading from Yukon.ca for now)
  # Update Yukon.ca links too
  formatted_news_release_html <- as.character(news_release_html) |> 
    str_replace_all('src="/sites/default/', 'src="https://yukon.ca/sites/default/') |> 
    str_replace_all('href="/en/', 'href="https://yukon.ca/en/') |> 
    str_replace_all('href="/fr/', 'href="https://yukon.ca/fr/')
  
  
  news_release_output <- str_c(
    formatted_html_template_start,
    formatted_news_release_html,
    html_template_end
  )
  
  write_file(
    news_release_output,
    file = html_output_path
    )
  
}


# retrieve_individual_news_release(
#   "https://yukon.ca/en/news/premier-sandy-silver-congratulates-yukons-2018-olympic-athletes", 
#   "2018", 
#   "18-024", 
#   "en", 
#   "Congrats!", 
#   "Meta description here."
#   )

for (i in seq_along(news_releases$node_id)) { 
  cat("Retrieving", news_releases$page_url[i], "\n")
  
  retrieve_individual_news_release(
    news_releases$page_url[i],
    news_releases$year[i],
    news_releases$news_release_number[i],
    news_releases$language[i],
    news_releases$title[i],
    news_releases$meta_description[i],
    news_releases$author[i],
    news_releases$publish_date[i],
    news_releases$archived_date[i],
    news_releases$archive_alert_message_text[i]
  )
  
}


run_end_time <- now()
paste("Start time was:", run_start_time)
paste("End time was:", run_end_time)

paste("Elapsed time was", round(time_length(interval(run_start_time, run_end_time), "hours"), digits = 2), "hours")
