screen_abstracts <- function(
  x = NULL
){

  data_in <- load_abstract_data(data = x)

  # create ui
  ui_data <- screen_abstracts_ui()
  ui <- shinydashboard::dashboardPage(
    title = "revtools | screen_abstracts",
  	ui_data$header,
  	ui_data$sidebar,
  	ui_data$body,
  	skin = "black"
  )

  # start server
  server <- function(input, output, session){

    # build reactive values
    data <- reactiveValues(
      raw = data_in$data$raw
    )
    progress <- reactiveValues(
      current = data_in$progress$current,
      row = data_in$progress$row
    )
    display <- reactiveValues(
      notes = FALSE
    )

    # create header image
    output$header <- renderPlot({
      revtools_logo(text = "screen_abstracts")
    })

    # DATA INPUT
    ## when specified, ensure input data is processed correctly
    observeEvent(input$data_in, {
      if(is.null(data$raw)){
        data_previous <- data_in$raw
      }else{
        data_previous <- data$raw
      }
      import_result <- import_shiny(
        source = input$data_in,
        current_data = data_previous
      )
      import_result <- add_abstract_columns(import_result)

      # export to reactiveValues
      data$raw <- import_result
      progress$row <- which(data$raw[, input$order] == progress$current)
    })

    # ABSTRACT SCREENING
    # change order of articles as necessary
    observeEvent(input$order, {
      progress$current <- 1
      progress$row <- which(data$raw[, input$order] == progress$current)
    })

    # display text for the current entry
    # note that observe is necessary to force changes when input$order changes
    observe({
      output$citation <- renderPrint({
        validate(
          need(data$raw, "Import data to begin")
        )
        if(any(colnames(data$raw) == "abstract")){
          abstract_text <- data$raw$abstract[progress$row]
        }else{
          abstract_text <- "<em>No abstract available</em>"
        }
        cat(
          paste0(
            "<font color =",
            data$raw$color[progress$row],
            ">",
            format_citation(
              data$raw[progress$row, ],
              abstract = FALSE,
              details = (input$hide_names == FALSE),
              add_html = TRUE
            ),
            "<br>",
            switch(as.character(data$raw$color[progress$row]),
              "#000000" = "",
              "#405d99" = "<em>Status: Selected</em>",
              "#993f3f" = "<em>Status: Excluded</em>"
            ),
            "<br><br>",
           abstract_text,
           "</font>"
         )
        )
      })
    })

    # RENDER SELECTION BUTTONS
    output$selector_buttons <- renderUI({
      if(!is.null(data$raw)){
        div(
          list(
            actionButton(
              inputId = "select_yes",
              label = "Select",
              style = "
                background-color: #7c93c1;
                color: #fff;
                width: 100px"
            ),
            br(),
            br(),
            actionButton(
              inputId = "select_no",
              label = "Exclude",
              style = "
                background-color: #c17c7c;
                color: #fff;
                width: 100px"
            ),
            br(),
            br(),
            div(
              style = "
                display: inline-block;
                vertical-align: top;
                width: 55px",
              actionButton(
                inputId = "abstract_previous",
                label = "<",
                width = "45px",
                style = "background-color: #6b6b6b;"
              )
            ),
            div(
              style = "
                display: inline-block;
                vertical-align: top;
                width: 45px",
              actionButton(
                inputId = "abstract_next",
                label = ">",
                width = "45px",
                style = "background-color: #6b6b6b;"
              )
            ),
            br(),
            br(),
            actionButton(
              inputId = "notes_toggle",
              label = "Notes",
              style = "
                background-color: #adadad;
                color: #fff;
                width: 100px"
            ),
            br()
          )
        )
      }
    })

    output$progress_text <- renderPrint({
      if(!is.null(data$raw)){
        HTML(
          paste0(
            "<br>",
            length(which(data$raw$selected == "selected")) +
            length(which(data$raw$selected == "excluded")),
            " of ",
            nrow(data$raw),
            " entries screened"
          )
        )
      }
    })

    # when toggle is triggered, invert display status of notes
    observeEvent(input$notes_toggle, {
      display$notes <- !display$notes
    })

    # render notes
    output$render_notes <- renderUI({
      if(display$notes){
        div(
          list(
            br(),
            textAreaInput(
              inputId = "abstract_notes",
              label = NULL,
              value = data$raw$notes[progress$row],
              resize = "vertical",
              width = "100%",
              height = "150px"
            ),
            actionButton(
              inputId = "notes_save",
              label = "Save Notes",
              width = "100px"
            ),
            br()
          )
        )
      }
    })

    # save notes
    observeEvent(input$notes_save, {
      data$raw$notes[progress$row] <- input$abstract_notes
    })

    # record & respond to user inputs
    observeEvent(input$select_yes, {
      data$raw$selected[progress$row] <- "selected"
      data$raw$color[progress$row] <- "#405d99"
      # if(display$notes){
      #   data$raw$notes[progress$row] <- input$abstract_notes
      # }
    })

    observeEvent(input$select_no, {
      data$raw$selected[progress$row] <- "excluded"
      data$raw$color[progress$row] <- "#993f3f"
    })

    observeEvent(input$abstract_next, {
      test_add <- which(data$raw[, input$order] == progress$current + 1)
      if(length(test_add) > 0){
        progress$current <- progress$current + 1
        progress$row <- which(data$raw[, input$order] == progress$current)
      }
    })

    observeEvent(input$abstract_previous, {
      if((progress$current - 1) > 0){
        progress$current <- progress$current - 1
        progress$row <- which(data$raw[, input$order] == progress$current)
      }
    })

    # SAVE OPTIONS
    observeEvent(input$save_data, {
      if(is.null(data$raw)){
        showModal(
          modalDialog(
            HTML(
              "Import some data to begin<br><br>
              <em>Click anywhere to exit</em>"
            ),
            title = "Error: no data to save",
            footer = NULL,
            easyClose = TRUE
          )
        )
      }else{
        showModal(
          modalDialog(
            textInput("save_filename",
              label = "File Name"
            ),
            selectInput("save_data_filetype",
              label = "File Type",
              choices = c("csv", "rds")
            ),
            actionButton("save_data_execute", "Save"),
            modalButton("Cancel"),
            title = "Save As",
            footer = NULL,
            easyClose = FALSE
          )
        )
      }
    })

    observeEvent(input$save_data_execute, {
      if(nchar(input$save_filename) == 0){
        filename <- "revtools_title_screening"
      }else{
        if(grepl("\\.[[:lower:]]{3}$", input$save_filename)){
          filename <- substr(
            input$save_filename, 1,
            nchar(input$save_filename) - 4
          )
        }else{
          filename <- input$save_filename
        }
      }
      filename <- paste(filename, input$save_data_filetype, sep = ".")
      switch(input$save_data_filetype,
        "csv" = {write.csv(data$raw, file = filename, row.names = FALSE)},
        "rds" = {saveRDS(data$raw, file = filename)}
      )
      removeModal()
    })

    # add option to remove data
    observeEvent(input$clear_data, {
      shiny::showModal(
        shiny::modalDialog(
          HTML("If you proceed, all data will be removed from this window,
          including any progress you have made screening your data.
          If you have not saved your data,
          you might want to consider doing that first.<br><br>
          Are you sure you want to continue?<br><br>"
          ),
          shiny::actionButton(
            inputId = "clear_data_confirmed",
            label = "Confirm"),
          shiny::modalButton("Cancel"),
          title = "Clear all data",
          footer = NULL,
          easyClose = FALSE
        )
      )
    })

    observeEvent(input$clear_data_confirmed, {
      data$raw <- NULL
      progress$current <- 1
      progress$row <- NULL
      display$notes <- FALSE
      removeModal()
    })

    observeEvent(input$exit_app, {
      exit_modal()
    })

    observeEvent(input$exit_app_confirmed, {
      stopApp(returnValue = invisible(data$raw))
    })

  } # end server

  print(shinyApp(ui, server))

}