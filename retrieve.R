library(tidyverse)
library(fs)
library(readxl)
library(rmarkdown)
library(janitor)
library(rvest)


# Helper functions --------------------------------------------------------

run_log <- tribble(
  ~time, ~message
)

# Logging helper function
add_log_entry <- function(log_text) {
  
  new_row = tibble_row(
    time = now(),
    message = log_text
  )
  
  run_log <<- run_log |>
    bind_rows(
      new_row
    )
  
  cat(log_text, "\n")
}

download_log <- tribble(
  ~time, ~url, ~filesize
)

add_download_log_entry <- function(url, filesize) {
  
  new_row = tibble_row(
    time = now(),
    url = url,
    filesize = filesize
  )
  
  download_log <<- download_log |>
    bind_rows(
      new_row
    )
}

# Start retrieval process -------------------------------------------------

run_start_time <- now()
add_log_entry(str_c("Start time was: ", run_start_time))

news_releases <- read_xlsx("input/yukon.ca-news-releases-published-2018-2021.xlsx")

html_template_start <- read_file("templates/start.html")
html_template_end <- read_file("templates/end.html")

# Today's date in YYYY-MM-DD format:
meta_archived_date <- str_sub(now(), 0L, 10L)

# Testing: limit to a subset of news releases
# news_releases <- news_releases |>
#   slice_head(n = 5)

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
      language == "fr" ~ 'Ce communiqué a été archivé. <a href="https://yukon.ca/fr/communiques-de-presse">Consulter les derniers communiqués du gouvernement du Yukon</a>.',
      .default = 'This news release has been archived. <a href="https://yukon.ca/news">View current Government of Yukon news</a>.'
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
    add_log_entry(str_c("- Path ", html_output_path, " already exists."))
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
  
  # Log how much text there was as a retrieval error check
  add_download_log_entry(page_url, str_length(formatted_news_release_html))
  
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
  add_log_entry(str_c("Retrieving ", news_releases$page_url[i]))
  
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
run_elapsed_hours <- round(time_length(interval(run_start_time, run_end_time), "hours"), digits = 2)

add_log_entry(str_c("End time was: ", run_end_time))
add_log_entry(str_c("Elapsed time was: ", run_elapsed_hours, " hours"))

# Write the log files to CSV:
run_log |> 
  write_csv("output_log/run_log.csv")

if(count(download_log) > 0) {
  download_log |> 
    write_csv("output_log/download_log.csv")
}

# Produce a redirects helper file
# with per-language destination URLs to the publication page:
redirects_list <- news_releases |> 
  mutate(
    from_url = page_url,
    to_url = case_when(
      language == "fr" ~ str_c("https://open.yukon.ca/information/communiques-de-presse-", year),
      .default = str_c("https://open.yukon.ca/information/news-releases-", year)
    )
  ) |> select(
    from_url,
    to_url,
    node_id
  )

redirects_list |> 
  write_csv("output_log/redirects_list.csv")
