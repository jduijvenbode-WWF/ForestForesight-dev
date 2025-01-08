#' Find Duplicate Function Names Across R Files
#'
#' @param directory Path to the directory containing R scripts
#' @return Data frame of duplicate functions and their locations
#' @import utils
find_duplicate_functions <- function(directory) {
  # Get all R files in directory
  r_files <- list.files(directory, pattern = "\\.R$", full.names = TRUE)

  # Store function names and their locations
  function_locations <- data.frame(
    function_name = character(),
    file = character(),
    line_number = numeric(),
    stringsAsFactors = FALSE
  )

  # Regular expression to match function definitions
  # Matches: function_name <- function(...) or function_name = function(...)
  fn_pattern <- "^\\s*([[:alnum:]_.]+)\\s*(<-|=)\\s*function\\s*\\("

  # Process each file
  for (file in r_files) {
    # Read file lines
    lines <- readLines(file)

    # Find function definitions
    for (i in seq_along(lines)) {
      matches <- regexec(fn_pattern, lines[i])
      if (matches[[1]][1] > 0) {
        # Extract function name from the match
        fn_name <- substr(lines[i],
                          matches[[1]][2],
                          matches[[1]][2] + attr(matches[[1]], "match.length")[2] - 1)

        # Add to data frame
        function_locations <- rbind(function_locations,
                                    data.frame(function_name = fn_name,
                                               file = basename(file),
                                               line_number = i,
                                               stringsAsFactors = FALSE))
      }
    }
  }

  # Find duplicates
  duplicates <- function_locations[duplicated(function_locations$function_name) |
                                     duplicated(function_locations$function_name, fromLast = TRUE), ]

  if (nrow(duplicates) > 0) {
    # Sort by function name and file
    duplicates <- duplicates[order(duplicates$function_name, duplicates$file), ]
    return(duplicates)
  } else {
    message("No duplicate function names found.")
    return(NULL)
  }
}
find_duplicate_functions("../../R")
# Example usage:
# duplicates <- find_duplicate_functions("path/to/your/R/scripts")
# if (!is.null(duplicates)) print(duplicates)
