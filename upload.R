library(tidyverse)
library(fs)
library(readxl)
library(rmarkdown)
library(janitor)
library(ckanr)
library(httr)


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


parent_dataset <- create_news_release_package_if_needed("2021")

# Create an associated resource
parent_dataset |> 
  resource_create(
    name = "Test 1027",
    description = "Description field.",
    upload = path("output", "en", "2018", "18-001.html"),
    verbose = TRUE,
    ssl_verifyhost = FALSE,
    ssl_verifypeer = FALSE
  )

