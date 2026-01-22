library(tidyverse)
library(fs)
library(readxl)
library(rmarkdown)
library(janitor)
library(ckanr)
library(httr)
library(lubridate)
library(DescTools)


# Initial setup -----------------------------------------------------------

run_start_time <- now()
paste("Start time:", run_start_time)

if(file_exists(".env")) {
  readRenviron(".env")
  
  ckan_url <- Sys.getenv("ckan_url")
  ckan_api_token <- Sys.getenv("ckan_api_token")
  
} else {
  stop("No .env file found, create it before running this script.")
}

ckanr_setup(
  url = ckan_url, 
  key = ckan_api_token
)

# Pasted in from retrieve.R
news_releases <- read_xlsx("input/yukon.ca-news-releases-published-2018-2021.xlsx")

# Testing: limit to a subset of news releases
news_releases <- news_releases |>
  # slice_head(n = 10)
  slice_sample(n = 10)


# Generate the current year from the date published field
# Plus hilariously over-engineered long date formatting to match previous archive resource titles
news_releases <- news_releases |> 
  mutate(
    year = str_sub(publish_date, 0L, 4L)
  ) |> 
  mutate(
    formatted_date = str_replace(Format(parse_date(publish_date), fmt = "mmmm d, yyyy"), "  ", " ")
  )

# Clean up some poorly-formatted news release numbers
news_releases <- news_releases |> 
  mutate(
    news_release_number = str_replace_all(news_release_number, "#", ""),
  ) |> 
  mutate(
    news_release_number = str_replace_all(news_release_number, "=", "-"),
  )

# Order the news releases by year, language (EN then FR), then reverse chronological date for display on dataset pages
news_releases <- news_releases |>
  arrange(
    desc(year),
    language,
    desc(publish_date)
  )

# Template text -----------------------------------------------------------

template_en_title <- "News releases {year}"
template_fr_title <- "Communiqués de presse {year}"

template_en_description <- "All {year} news releases.\n\nFor current Government of Yukon news, visit [Yukon.ca/news](https://yukon.ca/news)."
template_fr_description <- "Tous les communiqués de presse de {year}.\n\nPour les dernières nouvelles, visitez [Yukon.ca/fr/communiques-de-presse](https://yukon.ca/fr/communiques-de-presse)."


# Helper functions --------------------------------------------------------

# Thanks, Google
slugify <- function(x) {
  x %>%
    str_to_lower() %>%                        # Convert to lowercase
    str_replace_all("[^a-z0-9\\s-]", "") %>%  # Remove non-alphanumeric (except spaces/hyphens)
    str_squish() %>%                          # Remove extra whitespace
    str_replace_all("\\s+", "-")              # Replace spaces with hyphens
}

get_name_from_title <- function(title) {
  slugify(title)
}

get_title_by_year <- function(year, language = "en") {
  
  if(language == "en") {
    str_glue(
      template_en_title,
      year = {{year}}
      )
  }
  else {
    str_glue(
      template_fr_title,
      year = {{year}}
    )
  }
  
}

get_description_by_year <- function(year, language = "en") {
  
  if(language == "en") {
    str_glue(
      template_en_description,
      year = {{year}}
    )
  }
  else {
    str_glue(
      template_fr_description,
      year = {{year}}
    )
  }
  
}

create_news_release_package_if_needed <- function(news_year) {
  
  package_name <- get_name_from_title(get_title_by_year(news_year))
  
  # Check if package exists
  result = tryCatch({
    
    package_show(
      id = package_name,
      verbose = TRUE,
      ssl_verifyhost = FALSE,
      ssl_verifypeer = FALSE
      )

    
  }, error = function(e) {
    cat("Creating package ", package_name, "!.\n")
    
    package_create(
      name = get_name_from_title(get_title_by_year(news_year)),
      title = get_title_by_year(news_year),
      notes = get_description_by_year(news_year),
      type = "information",
      license_id = "OGL-Yukon-2.0",
      owner_org = "576049b0-490d-45d2-b236-31aef7a16ffe",
      
      extras = list(
        internal_contact_email = "ecoinfo@yukon.ca",
        internal_contact_name = "ECO Info",
        publication_required_under_atipp_act = "Yes",
        publication_type_under_atipp_act = "organizational_responsibilities_and_functions"
      ),
      
      verbose = TRUE,
      ssl_verifyhost = FALSE,
      ssl_verifypeer = FALSE
    )
    

  })

  
}


crul::set_verbose()
crul::curl_verbose(data_out = TRUE, data_in = TRUE, info = TRUE, ssl = TRUE)

crul::set_proxy(crul::proxy(url = "https://127.0.0.1:8888"))


# parent_dataset <- create_news_release_package_if_needed("2021")

# # Create an associated resource
# parent_dataset |> 
#   resource_create(
#     name = "Test 1027",
#     description = "Description field.",
#     upload = path("output", "en", "2018", "18-001.html"),
#     verbose = TRUE,
#     ssl_verifyhost = FALSE,
#     ssl_verifypeer = FALSE
#   )



# Add resources year-by-year ----------------------------------------------

news_release_years <- news_releases |> 
  select(year) |> 
  distinct() |> 
  arrange(year) |> 
  pull(year)


add_resources_by_year <- function(news_year) {
  
  current_year_news_releases <- news_releases |> 
    filter(year == news_year)
  
  cat("For ", news_year, "there are: ")
  count(current_year_news_releases)
  
  # Retrieve the current year's dataset (and create it first if needed)
  parent_dataset <- create_news_release_package_if_needed(news_year)
  
  # Add resources for each row in current_year_news_releases
  for (i in seq_along(current_year_news_releases$node_id)) { 
    
    cat("Uploading resource for ", current_year_news_releases$news_release_number[i], "\n")
    
    html_resource_path <- path("output", current_year_news_releases$language[i], current_year_news_releases$year[i], str_c(current_year_news_releases$news_release_number[i], ".html"))
    
    cat("From path ", html_resource_path)
    
    parent_dataset |> 
      resource_create(
        name = str_c(current_year_news_releases$title[i], ", ", current_year_news_releases$formatted_date[i]),
        description = current_year_news_releases$meta_description[i],
        upload = html_resource_path,
        verbose = TRUE,
        ssl_verifyhost = FALSE,
        ssl_verifypeer = FALSE
      )
    
    Sys.sleep(0.5)
    
  }
  
  
}

# add_resources_by_year("2018")

# For each of the years in the source spreadsheet, add all of that year's resources:
for (i in seq_along(news_release_years)) { 
  
  add_resources_by_year(news_release_years[i])
  
}
