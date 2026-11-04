library(shiny)

project_root <- normalizePath("..", mustWork = TRUE)
source(file.path(project_root, "R", "decision_model.R"))
source(file.path(project_root, "R", "dashboard_data.R"))
model_inputs <- load_dashboard_inputs(file.path(project_root, "data"))
scenario_names <- c(continue = "Continue plan", flex = "Flex worker",
                    reassign_overtime = "Reassign capacity")
short_names <- c(continue = "Continue", flex = "Flex", reassign_overtime = "Reassign")
scenario_colors <- c(continue = "#89969d", flex = "#db8b46",
                     reassign_overtime = "#26758a")

ui <- fluidPage(
  tags$head(tags$style(HTML("\n    body {background:#f4f7f6;color:#20333b;font-family:Arial,sans-serif;}
    .container-fluid {max-width:1280px;padding:24px 28px 48px;}
    .hero {background:#173e4c;color:white;padding:26px 32px;border-radius:14px;margin-bottom:22px;}
    .hero h1 {font-size:30px;font-weight:700;margin:0 0 7px;}
    .hero p {margin:0;color:#d3e5e7;font-size:15px;}
    .panel-box {background:white;border:1px solid #dce5e5;border-radius:12px;padding:20px;margin-bottom:18px;}
    .panel-box h3 {font-size:18px;margin:0 0 15px;font-weight:700;}
    .reco {border-left:6px solid #26758a;background:#e9f4f3;}
    .reco h2 {margin:5px 0 10px;font-size:25px;color:#173e4c;}
    .eyebrow {font-size:12px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:#356677;}
    .note {color:#53676f;font-size:13px;line-height:1.5;}
    .control-label {font-weight:700;}
    .irs--shiny .irs-bar,.irs--shiny .irs-single {background:#26758a;border-color:#26758a;}
    .table {font-size:13px;}
    .table th {background:#e8f0ef;}
    @media(max-width:768px) {.container-fluid {padding:12px;} .hero {padding:20px;} .hero h1 {font-size:24px;}}
  "))),
  div(class = "hero",
      h1("Manufacturing Disruption Decision Tool"),
      p("A synthetic, fixed-seed R simulation of a three-stage production line")),
  fluidRow(
    column(3,
      div(class = "panel-box",
          h3("Scenario input"),
          sliderInput("defect_rate", "Post-shock defect rate", min = 0,
                      max = 30, value = 12, step = 1, post = "%"),
          p(class = "note", "The rate rises after hour 4. Before the shock it remains 2%. Orders, capacities, and unit-level random draws stay fixed.")),
      div(class = "panel-box",
          h3("Decision rule"),
          p("1. Most fully delivered on-time orders"),
          p("2. Lowest estimated total cost"),
          p(class = "note", "Costs are illustrative USD assumptions. This tool is not a validated factory forecast."))),
    column(9,
      uiOutput("recommendation"),
      fluidRow(
        column(6, div(class = "panel-box", h3("On-time orders"), plotOutput("service_plot", height = "260px"))),
        column(6, div(class = "panel-box", h3("Estimated total cost"), plotOutput("cost_plot", height = "260px")))),
      div(class = "panel-box", h3("Good units shipped over the day"),
          plotOutput("flow_plot", height = "290px"),
          p(class = "note", "Gray: Continue · Orange: Flex · Blue: Reassign · Dashed line: defect shock at hour 4")),
      div(class = "panel-box", h3("All decision measures"),
          div(style = "overflow-x:auto;", tableOutput("comparison_table")),
          p(class = "note", "WIP is unfinished work at hour 10. A response uses overtime only if orders remain incomplete after the normal shift.")))))

server <- function(input, output, session) {
  result <- reactive(compare_at_defect_rate(input$defect_rate / 100, model_inputs))

  output$recommendation <- renderUI({
    x <- result()
    winner <- x$comparison[x$comparison$recommended, ]
    div(class = "panel-box reco", span(class = "eyebrow", "Rule-based recommendation"),
        h2(scenario_names[[x$recommended]]),
        p(sprintf("%d of %d orders on time · %d good units shipped · $%s estimated cost · %.1f overtime hours",
                  winner$on_time_orders, nrow(model_inputs$orders),
                  winner$good_units_shipped, format(winner$total_cost_usd, big.mark = ","),
                  winner$overtime_hours)),
        p(class = "note", "For this synthetic day only. The recommendation may change with another defect rate or calibrated inputs."))
  })

  output$service_plot <- renderPlot({
    x <- result()$comparison
    par(mar = c(4, 6, 1, 1), cex.axis = 0.8, cex.lab = 0.8)
    barplot(x$on_time_orders, names.arg = short_names[x$scenario],
            col = scenario_colors[x$scenario], border = NA, horiz = TRUE, las = 1,
            xlim = c(0, nrow(model_inputs$orders) + 0.5), xlab = "orders")
  }, res = 110, execOnResize = TRUE)

  output$cost_plot <- renderPlot({
    x <- result()$comparison
    par(mar = c(4, 6, 1, 1), cex.axis = 0.8, cex.lab = 0.8)
    barplot(x$total_cost_usd, names.arg = short_names[x$scenario],
            col = scenario_colors[x$scenario], border = NA, horiz = TRUE, las = 1,
            xlim = c(0, max(x$total_cost_usd) * 1.12), xlab = "synthetic USD")
  }, res = 110, execOnResize = TRUE)

  output$flow_plot <- renderPlot({
    x <- result()$runs
    time <- x[[1]]$bucket_log$bucket / 2
    totals <- lapply(x, function(run) cumsum(run$bucket_log$shipped))
    par(mar = c(4, 4, 1, 1), cex.axis = 0.8, cex.lab = 0.8)
    plot(time, totals[[1]], type = "l", lwd = 3, col = scenario_colors[1],
         xlim = c(0, max(time)), ylim = c(0, max(unlist(totals)) + 5),
         xlab = "hours", ylab = "good units shipped")
    for (i in 2:3) lines(time, totals[[i]], lwd = 3, col = scenario_colors[i])
    abline(v = 4, lty = 2, col = "#65767d")
  }, res = 110, execOnResize = TRUE)

  output$comparison_table <- renderTable({
    x <- result()$comparison
    data.frame(Response = scenario_names[x$scenario],
               `On-time orders` = x$on_time_orders,
               `Good units shipped` = x$good_units_shipped,
               `End WIP (units)` = x$end_wip_units,
               `Overtime (hours)` = x$overtime_hours,
               `Reworked (units)` = x$reworked_units,
               `Scrap (units)` = x$scrap_units,
               `Cost (synthetic USD)` = paste0("$", format(x$total_cost_usd, big.mark = ",")),
               check.names = FALSE)
  }, rownames = FALSE, striped = TRUE)
}

shinyApp(ui, server)
