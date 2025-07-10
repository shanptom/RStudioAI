# Gemini AI R / R Studio Integration 🤖

A simple and user-friendly R function to interact with Google's Gemini AI API directly from RStudio. Generate R code, get explanations, and automatically save responses as formatted R Markdown files.

## Features ✨

- **Easy Integration**: Call Gemini AI directly from R / RStudio
- **Contextual Understanding**: Provide context with R scripts or data files
- **Formatted Output**: Clean, readable responses with visual separators
- **R Markdown Export**: Save responses as .Rmd files with proper formatting
- **Error Handling**: Robust timeout and retry mechanisms
- **Customizable**: Multiple options for display and file saving

## Installation 📦

1. Clone this repository:
```bash
git clone https://github.com/yourusername/gemini-r-interface.git
```

2. Install required R packages:
```r
install.packages(c("httr", "jsonlite", "stringr"))
```

3. Source the function in R:
```r
source("ask_gemini.R")
```

## Setup 🔧

### Getting Your Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the generated API key

### Setting Up Environment Variables

#### Option 1: Using R (Recommended)
```r
# Set for current session
Sys.setenv(GEMINI_API_KEY = "your_api_key_here")

# Or add to .Renviron file for permanent setup
usethis::edit_r_environ()
# Add this line to the file: GEMINI_API_KEY=your_api_key_here
```

#### Option 2: System Environment Variables

**Windows:**
1. Open System Properties → Advanced → Environment Variables
2. Add new variable:
   - Name: `GEMINI_API_KEY`
   - Value: `your_api_key_here`
3. Restart RStudio

**macOS/Linux:**
1. Open terminal and edit your shell profile:
```bash
# For bash
echo 'export GEMINI_API_KEY="your_api_key_here"' >> ~/.bashrc

# For zsh
echo 'export GEMINI_API_KEY="your_api_key_here"' >> ~/.zshrc
```
2. Restart terminal and RStudio

**Alternative - .Renviron file:**
```r
# Create/edit .Renviron file in your home directory
file.edit("~/.Renviron")

# Add this line:
GEMINI_API_KEY=your_api_key_here
```

## Usage 🚀

### Basic Usage

```r
# Simple query
ask_gemini("Write an R function to calculate mean and standard deviation")

# Data visualization code
ask_gemini("Create a ggplot2 scatter plot with regression line")

# Statistical analysis
ask_gemini("Write R code for linear regression analysis")
```

### Advanced Usage

```r
# Save response as R Markdown file
ask_gemini_advanced("Write R code to create a line plot",
                   context_file = "path/to/your/data.csv",
                   context_files = c("analysis.R", "data.csv"),
                   save_to_file = TRUE,
                   open_file = TRUE,
                   custom_timeout = "100" #seconds)

# Custom filename
ask_gemini("Create a data cleaning function", 
           save_to_file = TRUE, 
           filename = "data_cleaning_script.Rmd")

# Get raw output without formatting
raw_response <- ask_gemini("Simple R question", format_output = FALSE)
```

## Function Parameters 📋

### `ask_gemini()`
- `prompt`: Your question/request to Gemini
- `api_key`: Your API key (uses environment variable by default)
- `format_output`: Whether to format the output (default: TRUE)
- `save_to_file`: Save response to file (default: FALSE)
- `filename`: Custom filename (optional)

### `ask_gemini_advanced()`
- `prompt`: Your question/request to Gemini
- `api_key`: Your API key (uses environment variable by default)
- `display_formatted`: Show formatted output (default: TRUE)
- `return_cleaned`: Return cleaned text (default: TRUE)
- `save_to_file`: Save response to file (default: FALSE)
- `filename`: Custom filename (optional)
- `open_file`: Automatically open saved file (default: FALSE)
- `context_file`: Single file path
- `context_files`: Vector of multiple file paths

```r
# Single file context
ask_gemini("Explain this code and suggest improvements", 
           context_file = "my_analysis.R")

# Multiple files context
ask_gemini_advanced("Compare these datasets and create a merged analysis", 
                   context_files = c("data1.csv", "data2.csv", "analysis.R"),
                   save_to_file = TRUE)

# Data file context
ask_gemini("Create a visualization for this dataset", 
           context_file = "sales_data.csv")

# Mixed context
ask_gemini("Review this analysis and suggest improvements",
           context_files = c("analysis.R", "data.csv", "notes.txt"))


## Output Format 📄

The function creates R Markdown files with:
- YAML header with title, author, and date
- Prompt section showing your original question
- Response section with properly formatted R code blocks
- Ready to knit to HTML, PDF, or Word


## Error Handling 🔧

The function includes:
- **Timeout handling**: 60-second timeout for API requests
- **Retry logic**: Up to 3 retry attempts for failed requests
- **API error handling**: Clear error messages for API issues
- **Network resilience**: Handles temporary connection issues

## Troubleshooting 🔍

### Common Issues

1. **"API key not found"**
   - Ensure your API key is set in environment variables
   - Check with `Sys.getenv("GEMINI_API_KEY")`

2. **"Timeout was reached"**
   - Check your internet connection
   - The function will automatically retry failed requests

3. **"API quota exceeded"**
   - You've reached your API usage limit
   - Check your usage at [Google AI Studio](https://aistudio.google.com/)

### Verify Setup
```r
# Check if API key is set
Sys.getenv("GEMINI_API_KEY")

# Test basic functionality
ask_gemini("Hello, can you write a simple R function?")
```

## Contributing 🤝

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License 📝

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments 🙏

- Google AI for the Gemini API
- R community for the excellent HTTP and JSON libraries
- Contributors and users who help improve this tool

## Support 💬

If you encounter any issues or have questions:
1. Check the troubleshooting section above
2. Open an issue on GitHub
3. Make sure your API key is properly configured

---

**Happy coding with Gemini AI! 🚀**
