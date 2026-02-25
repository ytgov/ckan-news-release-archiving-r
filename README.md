# ckan-news-release-archiving-r

This set of R scripts is used to archive [past news releases from Yukon.ca](https://yukon.ca/news) onto [open.yukon.ca](https://open.yukon.ca/information/).

The first script, `retrieve.R`, creates a set of small HTML files, one for each news release, that matches the formatting of the news release on Yukon.ca without the rest of the Yukon.ca menu and navigation interface.

The second script, `upload.R` uses the [CKAN API](https://docs.ckan.org/en/2.11/api/) to upload these files to the [Open Information section of open.yukon.ca](https://open.yukon.ca/information/), with one publication page (or "package", in the API documentation) per year. The script checks if that year's publication page already exists (it will create one for a given year if that year's page doesn't already exist). Then, it uploads all the HTML files as individual resources to that year's publication page. The script does not check if a news release has already been uploaded, it simply uploads all the news release HTML files for that year as individual resources.

These scripts use the [Tidyverse](https://tidyverse.org/) and several other R packages.

To upload files to CKAN, this requires the development version of [ckanr](https://github.com/ropensci/ckanr) (version 0.8.1 or higher, which as of 2026-02 is not yet available on CRAN).

## Initial setup

1. Install the R packages found in `upload.R` and `retrieve.R`.
2. Duplicate the `.env.example` file as `.env` and add your CKAN API token to the `.env` file (which is not Git-tracked).
3. Update the Excel sheet in the `input` folder with the set of news releases to archive.

In some cases, you may need to manually edit news release numbers in the Excel sheet to make sure these are unique (which is not guaranteed from the Yukon.ca output). If there are overlapping/conflicting news release numbers, you can append a `-1` or `-2` to the news release number. This is needed to make sure that all news releases are successfully retrieved, since the news release number is used as the HTML filename.

## Retrieve news release content

Run `retrieve.R`, which pulls the inner HTML of the news release content from the news release URL on Yukon.ca. (The news release must still be publicly accessible at the time this is run).

If the Yukon.ca template has changed significantly, adjust the `html_element` and `html_node` functions within `retrieve_individual_news_release()`.

You can adjust the "wrapper" template by editing the `start.html` and `end.html` templates in the `templates` folder. 

The `str_glue` function is used to "fill" the template values indicated with `{}` characters in the template files.

You can confirm that files were successfully downloaded by checking the string length (labelled "filesize") in the `output_log/download_log.csv` file.

The overall retrieval log is stored in `output_log/run_log.csv`. It typically takes about an hour to run.

A set of HTTP redirect recommendations are saved to `output_log/redirects_list.csv`.

## Upload news release HTML files to CKAN

Run `upload.R`, which uploads all of the HTML files to open.yukon.ca as individual resources for each year's news releases publication page.

If you get an HTTP error or CKAN error, make sure that your API token in `.env` is correct and that you're running the development version of ckanr.

