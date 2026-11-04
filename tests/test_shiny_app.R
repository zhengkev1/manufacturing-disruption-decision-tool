stopifnot(requireNamespace("shiny", quietly = TRUE))
app <- shiny::shinyAppDir("app")
stopifnot(inherits(app, "shiny.appobj"))
cat("Shiny app loads\n")
