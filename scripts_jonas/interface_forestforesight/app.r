# Load required libraries
library(shiny)
library(shinyjs)
library(terra)
library(lubridate)
library(future)
library(promises)
library(aws.s3)
library(shinydashboard)
library(leaflet)
library(gridExtra)
library(sf)
library(shinyWidgets)  # Add this for searchable dropdown

# Set up future to use multisession
plan(multisession)

# Load countries data
countries = vect(get(load("countries.rda")))

ui <- dashboardPage(
  dashboardHeader(title = "ForestForesight Data Explorer"),
  dashboardSidebar(
    sidebarMenu(
      radioButtons("input_type", "Select input type:",
                   choices = c("Country Selection" = "country", "File Upload" = "file"),
                   selected = "country"),
      conditionalPanel(
        condition = "input.input_type == 'country'",
        pickerInput(
          inputId = "country_select",
          label = "Select a country",
          choices = sort(unique(countries$name)),
          options = list(`live-search` = TRUE)
        )
      ),
      conditionalPanel(
        condition = "input.input_type == 'file'",
        fileInput("shape_file", "Upload Shapefile (zip), KML, or GeoJSON",
                  accept = c(".zip", ".kml", ".geojson"))
      ),
      actionButton("process", "Process Data", class = "btn-primary"),
      radioButtons("export_option", "Export Option:",
                   choices = list("GeoTIFF" = "geotiff",
                                  "PDF Report" = "pdf",
                                  "Polygonized GeoJSON" = "shapefile"),
                   selected = "geotiff"),
      downloadButton("download", "Download Results", class = "btn-success")
    )
  ),
  dashboardBody(
    useShinyjs(),
    tags$head(
      tags$style(HTML("
        .content-wrapper, .right-side {
          background-color: #ffffff;
        }
        #processing_indicator {
          color: #3c8dbc;
          font-weight: bold;
        }
        .error-message {
          color: red;
          font-weight: bold;
        }
        .warning-message {
          color: orange;
          font-weight: bold;
        }
      "))
    ),
    fluidRow(
      column(12,
             img(src = "ff_logo.png", height = "100px", style = "float: right;"),
             h2("Welcome to ForestForesight Data Explorer"),
             p("This application allows you to get easy and customized access to our monthly deforestation predictions. Follow these steps:"),
             tags$ol(
               tags$li("Choose between selecting a country or uploading your own shapefile."),
               tags$li("If selecting a country, choose from the dropdown. If uploading a file, select your shapefile (zip), KML, or GeoJSON."),
               tags$li("Click 'Process Data' to start the analysis."),
               tags$li("Select the desired output options."),
               tags$li("Once processing is complete, use 'Download Results' to get your data.")
             )
      )
    ),
    fluidRow(
      box(
        title = "Status and Progress",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        textOutput("status"),
        verbatimTextOutput("progress_log"),
        div(id = "processing_indicator", "Processing...", style = "display: none;"),
        htmlOutput("error_message"),
        htmlOutput("warning_message"),
        textOutput("reference_date")
      )
    ),
    fluidRow(
      box(
        title = "Prediction Map",
        status = "info",
        solidHeader = TRUE,
        width = 12,
        leafletOutput("map")
      )
    )
  )
)

server <- function(input, output, session) {
  values <- reactiveValues(
    shape = NULL,
    predictions_file = NULL,
    countries = NULL,
    progress_log = character(0),
    processing = FALSE,
    processing_complete = FALSE,
    error_message = NULL,
    warning_message = NULL,
    reference_date = NULL
  )

  update_progress <- function(message) {
    values$progress_log <- c(values$progress_log, paste(Sys.time(), "-", message))
  }

  output$progress_log <- renderText({
    paste(rev(values$progress_log), collapse = "\n")
  })

  output$error_message <- renderUI({
    if (!is.null(values$error_message)) {
      div(class = "error-message", values$error_message)
    }
  })

  output$warning_message <- renderUI({
    if (!is.null(values$warning_message)) {
      div(class = "warning-message", values$warning_message)
    }
  })

  output$reference_date <- renderText({
    if (!is.null(values$reference_date)) {
      paste("Reference Date:", values$reference_date)
    }
  })

  # Observe country selection
  observeEvent(input$country_select, {
    req(input$country_select)
    update_progress("Country selected. Ready to process data.")

    # Get the selected country's shape
    selected_country <- countries[countries$name == input$country_select]

    if (length(selected_country) == 0) {
      values$error_message <- "Selected country not found in the dataset."
      values$shape <- NULL
    } else {
      values$shape <- selected_country
      values$error_message <- NULL
    }
  })

  observeEvent(input$process, {
    req(values$shape)
    values$processing <- TRUE
    values$processing_complete <- FALSE
    update_progress("Starting data processing...")

    shinyjs::disable("process")
    shinyjs::show("processing_indicator")

    shape <- values$shape

    future_promise <- future({
      library(lubridate)
      cat("Starting asynchronous processing...\n")

      shape <- project(shape, "EPSG:4326")
      cat("Shape loaded and projected.\n")

      iso3_code <- shape$iso3
      cat("Processing country:", iso3_code, "\n")

      current_date <- Sys.Date()
      predictions_list <- list()
      reference_date <- NULL

      tryCatch({
        temp_dir <- tempdir()

        for (month_offset in 0:1) {
          date <- as.Date(format(current_date - month_offset * 30, "%Y-%m-01"))
          file_name <- sprintf("%s_%s.tif", iso3_code, format(date, "%Y-%m-%d"))
          s3_path <- paste0("predictions/", iso3_code, "/", file_name)
          local_path <- file.path(temp_dir, file_name)

          tryCatch({
            aws.s3::save_object(s3_path, local_path, bucket = "forestforesight-public", region = "eu-west-1")
            cat("File downloaded successfully:", local_path, "\n")

            if (file.size(local_path) > 1000) {
              predictions_list[[iso3_code]] <- terra::rast(local_path)
              if (is.null(reference_date)) {
                reference_date <- as.Date(substr(file_name, nchar(iso3_code) + 2, nchar(file_name) - 4))
                cat("Reference date set to:", reference_date, "\n")
              }
              break
            } else {
              cat("File size is too small, skipping:", local_path, "\n")
            }
          }, error = function(e) {
            cat("Error downloading file:", e$message, "\n")
            if (month_offset == 1) {
              cat("No valid prediction file found for", iso3_code, "\n")
            }
          })
        }
      }, error = function(e) {
        cat("Error processing", iso3_code, ":", e$message, "\n")
      })

      cat("Processing raster...\n")
      if (length(predictions_list) > 0) {
        result <- predictions_list[[1]]
        cat("Raster processed successfully.\n")

        # Crop and mask the result with the input shape
        result <- crop(result, shape)
        result <- mask(result, shape)
        result[result < 0.5] = NA
        cat("Result cropped and masked with input shape.\n")

        temp_tif <- tempfile(fileext = ".tif")
        writeRaster(result, temp_tif, overwrite = TRUE)
        cat("Processed raster saved to:", temp_tif, "\n")
      } else {
        result <- NULL
        temp_tif <- NULL
        cat("No predictions found for processing.\n")
      }

      list(
        predictions_file = temp_tif,
        iso3_code = iso3_code,
        reference_date = reference_date
      )
    }) %...>%
      (function(result) {
        update_progress(paste("Processed data for country:", result$iso3_code))
        if (!is.null(result$predictions_file)) {
          values$predictions_file <- result$predictions_file
          values$reference_date <- result$reference_date
          update_progress(paste("Predictions processed successfully. Reference date:", result$reference_date))

          # Update the map
          output$map <- renderLeaflet({
            predictions <- rast(values$predictions_file)
            pal <- colorNumeric(c("yellow", "orange", "red"), values(predictions), na.color = "transparent")
            leaflet() %>%
              addTiles() %>%
              addRasterImage(predictions, colors = pal, opacity = 1) %>%
              addLegend(pal = pal, values = values(predictions), title = "Prediction")
          })
        } else {
          update_progress("No predictions found for the selected country.")
        }
        values$countries <- result$iso3_code
        values$processing_complete <- TRUE
        values$processing <- FALSE
        shinyjs::enable("process")
        shinyjs::hide("processing_indicator")
      }) %>%
      catch(function(error) {
        update_progress(paste("Error during processing:", error$message))
        values$processing_complete <- FALSE
        values$processing <- FALSE
        shinyjs::enable("process")
        shinyjs::hide("processing_indicator")
      })
  })

  observe({
    if (values$processing_complete && !is.null(values$predictions_file)) {
      shinyjs::enable("download")
    } else {
      shinyjs::disable("download")
    }
  })

  output$download <- downloadHandler(
    filename = function() {
      switch(input$export_option,
             "geotiff" = "forestforesight_predictions.tif",
             "pdf" = "forestforesight_report.pdf",
             "shapefile" = "forestforesight_polygons.json")
    },
    content = function(file) {
      update_progress("Starting download process...")

      tryCatch({
        switch(input$export_option,
               "geotiff" = {
                 update_progress("Writing GeoTIFF...")
                 file.copy(values$predictions_file, file)
               },
               "pdf" = {
                 update_progress("Generating PDF...")

                 library(ggplot2)
                 library(basemaps)
                 library(grid)
                 library(gridExtra)
                 library(png)
                 library(raster)

                 # ... (rest of the PDF generation code remains the same)
               },
               "shapefile" = {
                 update_progress("Writing GeoJSON")
                 predictions <- rast(values$predictions_file)
                 polygons <- as.polygons(predictions)
                 writeVector(polygons, file, filetype = "GeoJSON")
               })

        update_progress("File written successfully.")
      }, error = function(e) {
        update_progress(paste("Error in download process:", e$message))
        stop(paste("Error in download process:", e$message))
      })
    }
  )
}

shinyApp(ui, server)
