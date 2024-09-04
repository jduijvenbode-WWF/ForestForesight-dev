# Load required libraries
library(shiny)
library(shinyjs)
library(terra)
library(lubridate)
library(tmap)
library(future)
library(promises)
library(aws.s3)
library(shinydashboard)
library(leaflet)
library(gridExtra)
library(mapview)
library(ggplot2)
library(sf)
library(webshot)

# Set up future to use multisession
plan(multisession)

# Load countries data
countries = vect(get(load("countries.rda")))

ui <- dashboardPage(
  dashboardHeader(title = "ForestForesight Data Explorer"),
  dashboardSidebar(
    sidebarMenu(
      fileInput("shape_file", "Upload Shapefile (zip), KML, or GeoJSON",
                accept = c(".zip", ".kml", ".geojson")),
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
               tags$li("Upload your shapefile (all shapefile files in a zip), KML, or GeoJSON file."),
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
        textOutput("reference_date")  # New output for reference date
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
    shape_file = NULL,
    predictions_file = NULL,
    countries = NULL,
    progress_log = character(0),
    processing = FALSE,
    processing_complete = FALSE,
    error_message = NULL,
    warning_message = NULL,
    reference_date = NULL  # New reactive value for reference date
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

  observeEvent(input$shape_file, {
    file <- input$shape_file
    ext <- tools::file_ext(file$datapath)

    update_progress("Starting to process uploaded file...")

    tryCatch({
      temp_dir <- tempdir()
      if (ext == "zip") {
        update_progress("Unzipping and reading shapefile...")
        unzip(file$datapath, exdir = temp_dir)
        shp_file <- list.files(temp_dir, pattern = "\\.shp$", full.names = TRUE)
        if (length(shp_file) == 0) stop("No .shp file found in the zip archive")
        values$shape_file <- shp_file
      } else {
        file.copy(file$datapath, file.path(temp_dir, file$name))
        values$shape_file <- file.path(temp_dir, file$name)
      }

      # Check if the uploaded file contains polygons
      shape <- vect(values$shape_file)
      if (!is(shape, "SpatVector") || geomtype(shape) != "polygons") {
        values$error_message <- "The uploaded file should contain polygons. Please upload a valid polygon dataset."
        values$shape_file <- NULL
        return()
      }

      # Check if the polygon intersects with countries between 30 degrees north and south latitude
      countries_30 <- crop(countries, ext(-180, 180, -30, 30))
      if (is.null(terra::intersect(shape, countries_30))) {
        values$error_message <- "We only process data in countries between 30 degrees north and south latitude. Please upload a file within this range."
        values$shape_file <- NULL
        return()
      }

      # Check if the polygon area is more than 30x30 degrees
      bbox <- ext(project(shape,"epsg:4326"))
      if (expanse(as.polygons(bbox))>3600) {
        values$error_message <- paste("The area of the polygon is too big (",expanse(as.polygons(bbox)), "degrees) Please upload a file with an area less than 30x30 degrees.")
        values$shape_file <- NULL
        return()
      }

      # Check if the polygon is partly overlapping with the countries
      if (any(is.na(terra::intersect(shape, countries_30)))) {
        values$warning_message <- "The uploaded polygon is partly outside the processing area. Only the overlapping part will be processed."
      }

      update_progress("Shape file processed successfully.")
      output$status <- renderText("Shape file loaded successfully.")
    }, error = function(e) {
      update_progress(paste("Error loading file:", e$message))
      output$status <- renderText(paste("Error loading file:", e$message))
    })
  })

  observeEvent(input$process, {
    req(values$shape_file)
    values$processing <- TRUE
    values$processing_complete <- FALSE
    update_progress("Starting data processing...")

    shinyjs::disable("process")
    shinyjs::show("processing_indicator")

    shape_file_path <- values$shape_file

    future_promise <- future({
      library(lubridate)
      cat("Starting asynchronous processing...\n")
      countries = vect(get(load("countries.rda")))
      shape <- vect(shape_file_path)
      shape <- project(shape, "EPSG:4326")
      cat("Shape loaded and projected.\n")

      overlapping_countries <- terra::intersect(shape, countries)
      iso3_codes <- unique(overlapping_countries$iso3)
      cat("Overlapping countries found:", paste(iso3_codes, collapse = ", "), "\n")

      current_date <- Sys.Date()
      predictions_list <- list()
      reference_date <- NULL

      for (iso3 in iso3_codes) {
        cat("Processing country:", iso3, "\n")
        tryCatch({
          temp_dir <- tempdir()

          for (month_offset in 0:1) {
            # Calculate the date without lubridate
            date <- as.Date(format(current_date - month_offset * 30, "%Y-%m-01"))
            file_name <- sprintf("%s_%s.tif", iso3, format(date, "%Y-%m-%d"))
            s3_path <- paste0("predictions/", iso3, "/", file_name)
            local_path <- file.path(temp_dir, file_name)

            tryCatch({
              aws.s3::save_object(s3_path, local_path, bucket = "forestforesight-public", region = "eu-west-1")
              cat("File downloaded successfully:", local_path, "\n")

              # Check file size
              if (file.size(local_path) > 1000) {
                predictions_list[[iso3]] <- terra::rast(local_path)
                if (is.null(reference_date)) {
                  reference_date <- as.Date(substr(file_name, nchar(iso3) + 2, nchar(file_name) - 4))
                  cat("Reference date set to:", reference_date, "\n")
                }
                break
              } else {
                cat("File size is too small, skipping:", local_path, "\n")
              }
            }, error = function(e) {
              cat("Error downloading file:", e$message, "\n")
              if (month_offset == 1) {
                cat("No valid prediction file found for", iso3, "\n")
              }
            })
          }
        }, error = function(e) {
          cat("Error processing", iso3, ":", e$message, "\n")
        })
      }

      cat("Mosaicing rasters...\n")
      if (length(predictions_list) > 0) {
        result <- terra::mosaic(terra::sprc(predictions_list))
        cat("Rasters mosaiced successfully.\n")

        # Crop and mask the result with the input shape
        result <- crop(result, shape)
        result <- mask(result, shape)
        result[result<0.5]=NA
        cat("Result cropped and masked with input shape.\n")

        temp_tif <- tempfile(fileext = ".tif")
        writeRaster(result, temp_tif, overwrite = TRUE)
        cat("Mosaiced raster saved to:", temp_tif, "\n")
      } else {
        result <- NULL
        temp_tif <- NULL
        cat("No predictions found for mosaicing.\n")
      }

      list(
        predictions_file = temp_tif,
        iso3_codes = iso3_codes,
        reference_date = reference_date
      )
    }) %...>%
      (function(result) {
        update_progress(paste("Found", length(result$iso3_codes), "overlapping countries:", paste(result$iso3_codes, collapse = ", ")))
        if (!is.null(result$predictions_file)) {
          values$predictions_file <- result$predictions_file
          values$reference_date <- result$reference_date
          update_progress(paste("Predictions processed and mosaiced successfully. Reference date:", result$reference_date))

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
          update_progress("No predictions found for the selected area.")
        }
        values$countries <- result$iso3_codes
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
                 adjust_extent_ratio <- function(polygon, ratio = 1.4) {
                   library(terra)

                   # Get the extent of the polygon
                   ext <- ext(polygon)

                   # Calculate current width and height
                   width <- ext[2] - ext[1]
                   height <- ext[4] - ext[3]

                   # Calculate the center point
                   center_x <- (ext[1] + ext[2]) / 2
                   center_y <- (ext[3] + ext[4]) / 2

                   # Calculate the target height and width
                   if (height / width >= ratio) {
                     # If current ratio is already larger than target, adjust width
                     new_width <- height / ratio
                     new_height <- height
                   } else {
                     # Otherwise, adjust height
                     new_height <- width * ratio
                     new_width <- width
                   }

                   # Calculate the differences
                   diff_x <- (new_width - width) / 2
                   diff_y <- (new_height - height) / 2

                   # Create new extent
                   new_ext <- c(center_x - new_width/2,
                                center_x + new_width/2,
                                center_y - new_height/2,
                                center_y + new_height/2)

                   # Return as an extent object
                   pol=as.polygons(ext(new_ext))
                   crs(pol)=crs("epsg:3857")

                   return(st_as_sf(pol))
                 }

                 plot_basemap_with_raster <- function(raster, filename,zoom = 12) {
                   library(basemaps)
                   library(terra)
                   library(sf)
                   # Get the extent of the raster
                   t1=as.polygons(ext(project(raster,"epsg:3857")))
                   crs(t1)=crs("epsg:3857")
                   ext <- adjust_extent_ratio(t1)
                    png(filename = filename,width = 595, height = 842, units = "px")
                   # Set the basemap extent and type
                   set_defaults(map_service = "carto", map_type = "light")
                   base_map <- basemap_terra(ext, zoom = zoom)


                   # Ensure the CRS of the raster matches the basemap
                   raster <- project(raster, crs(base_map))

                   # Plot the basemap

                   raster[raster<0.5]=NA

                   # Define the color palette (yellow to red)
                   col_pal <- colorRampPalette(c("yellow", "orange", "red"))

                   # Plot the basemap
                   plot(base_map)
                   Sys.sleep(3)

                   # Overlay the masked raster with the custom color palette
                   plot(raster, add = TRUE, alpha = 1, col = col_pal(100), legend = FALSE)
                   # Overlay the raster


                   # Add a title
                   title("ForestForesight Predictions")
                   dev.off()
                 }

                 predictions <- rast(values$predictions_file)

                 # Get the extent of the predictions
                 map=plot_basemap_with_raster(predictions,filename="temp_map.png")

                 # Save the map to a temporary file

                 plot_map_with_logo <- function(map_path, logo_path, output_file, reference_date = NULL) {
                   library(png)
                   library(grid)
                   library(gridExtra)

                   # Read the map and logo images
                   map_img <- png::readPNG(map_path)
                   logo <- png::readPNG(logo_path)

                   # Create grid graphics
                   map_grob <- rasterGrob(map_img, interpolate = TRUE, width = unit(1, "npc"), height = unit(1, "npc"))

                   # Calculate logo size (e.g., 15% of the map width)
                   logo_width <- 0.15
                   logo_height <- logo_width * (dim(logo)[1] / dim(logo)[2])
                   logo_grob <- rasterGrob(logo, interpolate = TRUE,
                                           width = unit(logo_width, "npc"),
                                           height = unit(logo_height, "npc"))

                   # Create the final plot
                   final_plot <- ggplotGrob(ggplot() +
                                              annotation_custom(map_grob, xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf) +
                                              annotation_custom(logo_grob, xmin = unit(1 - logo_width - 0.02, "npc"),
                                                                xmax = unit(0.98, "npc"),
                                                                ymin = unit(1 - logo_height - 0.02, "npc"),
                                                                ymax = unit(0.98, "npc")) +
                                              theme_void())

                   # Save as PDF
                   pdf(output_file, width = 8.5, height = 12)
                   grid.draw(final_plot)

                   # Add reference date to the PDF if provided
                   if (!is.null(reference_date)) {
                     grid.text(paste("Reference Date:", reference_date),
                               x = 0.98, y = 0.02, just = "right",
                               gp = gpar(fontsize = 10))
                   }

                   dev.off()
                 }
                 # Read the saved map and the logo
                 plot_map_with_logo("temp_map.png",
                                    "www/ff_logo.png",
                                    file,
                                    reference_date = values$reference_date)

                 update_progress("PDF generated successfully.")
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
