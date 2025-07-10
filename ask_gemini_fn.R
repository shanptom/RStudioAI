ask_gemini <- function(prompt, api_key = Sys.getenv("GEMINI_API_KEY"), 
                       format_output = TRUE, save_to_file = FALSE, 
                       filename = NULL, context_file = NULL) {
  
  # Load required libraries
  library(httr)
  library(jsonlite)
  library(stringr)
  
  # Handle context file if provided
  final_prompt <- prompt
  context_size <- 0
  
  if (!is.null(context_file)) {
    if (file.exists(context_file)) {
      # Read file content
      file_content <- readLines(context_file, warn = FALSE)
      file_text <- paste(file_content, collapse = "\n")
      context_size <- nchar(file_text)
      
      # Determine file type for better formatting
      file_ext <- tools::file_ext(context_file)
      file_type <- switch(tolower(file_ext),
                          "r" = "R",
                          "py" = "Python", 
                          "sql" = "SQL",
                          "csv" = "CSV",
                          "txt" = "Text",
                          "md" = "Markdown",
                          "rmd" = "R Markdown",
                          "json" = "JSON",
                          "Unknown")
      
      # Combine context with prompt
      final_prompt <- paste0(
        "Context: I'm providing you with a ", file_type, " file as context.\n\n",
        "File: ", basename(context_file), "\n",
        "```", tolower(file_ext), "\n",
        file_text, "\n",
        "```\n\n",
        "Based on this context, please help with the following:\n",
        prompt
      )
    } else {
      warning("Context file not found: ", context_file)
    }
  }
  
  # Calculate adaptive timeout based on content size
  total_size <- nchar(final_prompt)
  base_timeout <- 60
  
  # Adaptive timeout calculation:
  # - Base 60 seconds for requests under 10KB
  # - Add 10 seconds per 10KB of content
  # - Add 30 seconds per 100KB of content for very large files
  # - Maximum timeout of 10 minutes (600 seconds)
  if (total_size <= 10000) {
    timeout_seconds <- base_timeout
  } else if (total_size <= 100000) {
    timeout_seconds <- base_timeout + ceiling((total_size - 10000) / 10000) * 10
  } else {
    timeout_seconds <- base_timeout + 90 + ceiling((total_size - 100000) / 100000) * 30
  }
  
  # Cap at maximum timeout
  timeout_seconds <- min(timeout_seconds, 600)
  
  cat("Content size:", format(total_size, big.mark = ","), "characters\n")
  cat("Timeout set to:", timeout_seconds, "seconds\n")
  
  # Construct API URL
  url <- paste0("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=", api_key)
  
  # Prepare request body
  body <- list(
    contents = list(
      list(parts = list(list(text = final_prompt)))
    )
  )
  
  # Enhanced retry logic with exponential backoff
  max_retries <- 3
  retry_delay <- 2  # Starting delay in seconds
  
  for (attempt in 1:max_retries) {
    tryCatch({
      cat("Making API request (attempt", attempt, "of", max_retries, ")...\n")
      
      res <- POST(
        url,
        body = toJSON(body, auto_unbox = TRUE),
        content_type_json(),
        timeout(timeout_seconds)
      )
      
      # Check if request was successful
      if (status_code(res) == 200) {
        cat("✅ API request successful\n")
        break  # Success, exit retry loop
      } else {
        stop("HTTP ", status_code(res), ": ", content(res, as = "text"))
      }
      
    }, error = function(e) {
      if (attempt == max_retries) {
        stop("API request failed after ", max_retries, " attempts. Final error: ", e$message)
      }
      
      cat("❌ Attempt", attempt, "failed:", e$message, "\n")
      cat("⏳ Retrying in", retry_delay, "seconds...\n")
      Sys.sleep(retry_delay)
      
      # Exponential backoff: double the delay for next attempt
      retry_delay <<- retry_delay * 2
    })
  }
  
  # Parse response
  parsed <- content(res, as = "parsed")
  
  # Handle API errors
  if (!is.null(parsed$error)) {
    stop("Gemini API Error: ", parsed$error$message)
  }
  
  # Extract raw text
  raw_text <- parsed$candidates[[1]]$content$parts[[1]]$text
  
  if (format_output) {
    # Enhanced cleaning for better formatting
    cleaned_text <- raw_text |>
      # Remove code block markers
      str_remove_all("^```[a-zA-Z]*\\s*|```$") |>
      # Replace escaped newlines with actual newlines
      str_replace_all("\\\\n", "\n") |>
      # Replace escaped quotes
      str_replace_all('\\"', '"') |>
      # Replace escaped tabs
      str_replace_all("\\\\t", "\t") |>
      # Clean up multiple consecutive newlines
      str_replace_all("\n{3,}", "\n\n") |>
      # Remove leading/trailing whitespace
      str_trim()
    
    # Format and display the output nicely
    cat("\n" %+% paste(rep("=", 80), collapse = "") %+% "\n")
    cat("GEMINI RESPONSE\n")
    cat(paste(rep("=", 80), collapse = "") %+% "\n\n")
    cat(cleaned_text)
    cat("\n\n" %+% paste(rep("=", 80), collapse = "") %+% "\n")
    
    # Optional: Save to file
    if (save_to_file) {
      if (is.null(filename)) {
        filename <- paste0("gemini_response_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".Rmd")
      }
      
      # Create R Markdown formatted content
      rmd_content <- paste0(
        "---\n",
        "title: \"Gemini AI Response\"\n",
        "author: \"Generated by Gemini\"\n",
        "date: \"", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\"\n",
        "output: html_document\n",
        "---\n\n",
        "## Prompt\n\n",
        substr(prompt, 1, 200), ifelse(nchar(prompt) > 200, "...", ""), "\n\n",
        "## Response\n\n",
        "```{r}\n",
        cleaned_text, "\n",
        "```"
      )
      
      writeLines(rmd_content, filename)
      cat("Response saved to:", filename, "\n")
    }
    
    # Return cleaned text invisibly so it doesn't print again
    invisible(cleaned_text)
    
  } else {
    # Return raw text without formatting
    return(raw_text)
  }
}

# Helper function for string concatenation (if %+% doesn't exist)
`%+%` <- function(a, b) paste0(a, b)

# Enhanced version with additional options and improved timeout handling
ask_gemini_advanced <- function(prompt, api_key = Sys.getenv("GEMINI_API_KEY"),
                                display_formatted = TRUE, 
                                return_cleaned = TRUE,
                                save_to_file = FALSE,
                                filename = NULL,
                                open_file = FALSE,
                                context_file = NULL,
                                context_files = NULL,
                                custom_timeout = NULL) {
  
  library(httr)
  library(jsonlite)
  library(stringr)
  
  # Handle context files if provided
  final_prompt <- prompt
  context_info <- ""
  total_context_size <- 0
  
  # Handle multiple context files
  all_context_files <- c(context_file, context_files)
  all_context_files <- all_context_files[!is.null(all_context_files)]
  
  if (length(all_context_files) > 0) {
    context_parts <- c()
    
    for (file_path in all_context_files) {
      if (file.exists(file_path)) {
        # Read file content
        file_content <- readLines(file_path, warn = FALSE)
        file_text <- paste(file_content, collapse = "\n")
        total_context_size <- total_context_size + nchar(file_text)
        
        # Determine file type
        file_ext <- tools::file_ext(file_path)
        file_type <- switch(tolower(file_ext),
                            "r" = "R",
                            "py" = "Python", 
                            "sql" = "SQL",
                            "csv" = "CSV",
                            "txt" = "Text",
                            "md" = "Markdown",
                            "rmd" = "R Markdown",
                            "json" = "JSON",
                            "xml" = "XML",
                            "html" = "HTML",
                            "js" = "JavaScript",
                            "Unknown")
        
        # Add file context
        context_parts <- c(context_parts, paste0(
          "File: ", basename(file_path), " (", file_type, ")\n",
          "```", tolower(file_ext), "\n",
          file_text, "\n",
          "```\n"
        ))
      } else {
        warning("Context file not found: ", file_path)
      }
    }
    
    if (length(context_parts) > 0) {
      context_info <- paste0(
        "Context: I'm providing you with ", length(context_parts), 
        " file(s) as context.\n\n",
        paste(context_parts, collapse = "\n"),
        "\n"
      )
      
      final_prompt <- paste0(
        context_info,
        "Based on this context, please help with the following:\n",
        prompt
      )
    }
  }
  
  # Calculate adaptive timeout based on total content size
  total_size <- nchar(final_prompt)
  
  if (!is.null(custom_timeout)) {
    timeout_seconds <- custom_timeout
    cat("Using custom timeout:", timeout_seconds, "seconds\n")
  } else {
    base_timeout <- 120  # Increased base timeout for advanced function
    
    # More sophisticated timeout calculation for multiple files
    if (total_size <= 10000) {
      timeout_seconds <- base_timeout
    } else if (total_size <= 50000) {
      timeout_seconds <- base_timeout + ceiling((total_size - 10000) / 5000) * 15
    } else if (total_size <= 200000) {
      timeout_seconds <- base_timeout + 120 + ceiling((total_size - 50000) / 25000) * 30
    } else {
      timeout_seconds <- base_timeout + 300 + ceiling((total_size - 200000) / 100000) * 60
    }
    
    # Cap at maximum timeout of 15 minutes for very large contexts
    timeout_seconds <- min(timeout_seconds, 900)
  }
  
  # Display size and timeout information
  cat("📊 Content analysis:\n")
  cat("  - Total size:", format(total_size, big.mark = ","), "characters\n")
  cat("  - Context size:", format(total_context_size, big.mark = ","), "characters\n")
  cat("  - Files processed:", length(all_context_files), "\n")
  cat("  - Timeout set to:", timeout_seconds, "seconds (", round(timeout_seconds/60, 1), "minutes)\n\n")
  
  url <- paste0("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=", api_key)
  
  body <- list(
    contents = list(
      list(parts = list(list(text = final_prompt)))
    )
  )
  
  # Enhanced retry logic with progressive timeout increases
  max_retries <- 4  # Increased retries for large contexts
  retry_delay <- 3
  
  for (attempt in 1:max_retries) {
    # Increase timeout for each retry attempt
    current_timeout <- timeout_seconds + ((attempt - 1) * 60)
    
    tryCatch({
      cat("🔄 Making API request (attempt", attempt, "of", max_retries, ")...\n")
      cat("   Timeout for this attempt:", current_timeout, "seconds\n")
      
      # Start timing the request
      start_time <- Sys.time()
      
      res <- POST(
        url,
        body = toJSON(body, auto_unbox = TRUE),
        content_type_json(),
        timeout(current_timeout)
      )
      
      end_time <- Sys.time()
      request_duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
      
      # Check if request was successful
      if (status_code(res) == 200) {
        cat("✅ API request successful in", round(request_duration, 1), "seconds\n")
        break  # Success, exit retry loop
      } else {
        stop("HTTP ", status_code(res), ": ", content(res, as = "text"))
      }
      
    }, error = function(e) {
      if (attempt == max_retries) {
        stop("API request failed after ", max_retries, " attempts. Final error: ", e$message)
      }
      
      cat("❌ Attempt", attempt, "failed:", e$message, "\n")
      
      # Special handling for timeout errors
      if (grepl("timeout", e$message, ignore.case = TRUE)) {
        cat("⏰ Request timed out. Increasing timeout for next attempt.\n")
      }
      
      cat("⏳ Retrying in", retry_delay, "seconds...\n")
      Sys.sleep(retry_delay)
      
      # Exponential backoff with jitter
      retry_delay <<- retry_delay * 1.5 + sample(1:3, 1)
    })
  }
  
  parsed <- content(res, as = "parsed")
  
  if (!is.null(parsed$error)) {
    stop("Gemini API Error: ", parsed$error$message)
  }
  
  raw_text <- parsed$candidates[[1]]$content$parts[[1]]$text
  
  # Enhanced text cleaning
  cleaned_text <- raw_text |>
    str_remove_all("^```[a-zA-Z]*\\s*|```$") |>
    str_replace_all("\\\\n", "\n") |>
    str_replace_all('\\"', '"') |>
    str_replace_all("\\\\t", "\t") |>
    str_replace_all("\n{3,}", "\n\n") |>
    str_trim()
  
  if (display_formatted) {
    # Create a nice header
    header <- paste(rep("=", 80), collapse = "")
    cat("\n", header, "\n")
    cat("🤖 GEMINI RESPONSE\n")
    cat(header, "\n\n")
    
    # Display the cleaned text
    cat(cleaned_text)
    
    # Create footer
    cat("\n\n", header, "\n")
    cat("✅ Response generated at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
    cat("📝 Response length:", format(nchar(cleaned_text), big.mark = ","), "characters\n")
    cat(header, "\n")
  }
  
  # Save to file if requested
  if (save_to_file) {
    if (is.null(filename)) {
      filename <- paste0("gemini_response_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".Rmd")
    }
    
    # Create R Markdown formatted content
    rmd_content <- paste0(
      "---\n",
      "title: \"Gemini AI Response\"\n",
      "author: \"Generated by Gemini\"\n",
      "date: \"", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\"\n",
      "output: html_document\n",
      "---\n\n",
      "## Prompt\n\n",
      substr(prompt, 1, 200), ifelse(nchar(prompt) > 200, "...", ""), "\n\n",
      "## Context Files\n\n",
      if (length(all_context_files) > 0) {
        paste("- ", basename(all_context_files), collapse = "\n")
      } else {
        "No context files provided"
      }, "\n\n",
      "## Response\n\n",
      "```{r}\n",
      cleaned_text, "\n",
      "```"
    )
    
    writeLines(rmd_content, filename)
    cat("💾 Response saved to:", filename, "\n")
    
    # Optionally open the file
    if (open_file && interactive()) {
      file.edit(filename)
    }
  }
  
  # Return based on preference
  if (return_cleaned) {
    invisible(cleaned_text)
  } else {
    invisible(raw_text)
  }
}

# Helper function to estimate processing time
estimate_processing_time <- function(context_files = NULL, prompt = "") {
  total_size <- nchar(prompt)
  
  if (!is.null(context_files)) {
    for (file_path in context_files) {
      if (file.exists(file_path)) {
        file_content <- readLines(file_path, warn = FALSE)
        file_text <- paste(file_content, collapse = "\n")
        total_size <- total_size + nchar(file_text)
      }
    }
  }
  
  # Rough estimation based on size
  if (total_size <= 10000) {
    estimate <- "30-90 seconds"
  } else if (total_size <= 50000) {
    estimate <- "1-3 minutes"
  } else if (total_size <= 200000) {
    estimate <- "3-7 minutes"
  } else {
    estimate <- "5-15 minutes"
  }
  
  cat("📊 Processing time estimate:", estimate, "\n")
  cat("📏 Total content size:", format(total_size, big.mark = ","), "characters\n")
  
  return(invisible(total_size))
}

# Example usage functions
demo_gemini <- function() {
  cat("Demo: Basic usage\n")
  ask_gemini("Write a simple R function to calculate mean and standard deviation")
  
  cat("\n\nDemo: Advanced usage with file saving\n")
  ask_gemini_advanced(
    "Create an R function for data visualization", 
    save_to_file = TRUE,
    filename = "gemini_viz_function.R"
  )
}