
data_total <- read.csv("confirmed.csv")
data_death <- read.csv("deaths.csv")
data_recovered <- read.csv("recovered.csv")

default_country <- "Afghanistan"
default_date <- "2020-06-04"

total <- data_total %>% filter(as.Date(dates, "%Y-%m-%d") == default_date & country == default_country) %>% summarise(total = sum(value))
death <- data_death %>% filter(as.Date(dates, "%Y-%m-%d") == default_date & country == default_country) %>% summarise(total = sum(value))
recovered <- data_recovered %>% filter(as.Date(dates, "%Y-%m-%d") == "2020-06-04" & country == default_country) %>% summarise(total = sum(value))
data_plot_series <- data_total %>% filter(country == default_country)

server <- function(input, output) {
  
  output$output_range_date <- renderUI({
    min_date <- data_total %>% mutate(date = ymd(dates)) %>% summarize(value_date = min(date))
    max_date <- data_total %>% mutate(date = ymd(dates)) %>% summarize(value_date = max(date))

    sliderInput(
      inputId = "slide_range_date",
      label = "Fecha:",
      min = as.Date(min_date$value_date,"%Y-%m-%d"),
      max = as.Date(max_date$value_date,"%Y-%m-%d"),
      value = as.Date("2020-06-04"),
      timeFormat="%Y-%m-%d")
  })
  
  output$output_select_country <- renderUI({
    items_country <- data_total %>% distinct(country)
    selectInput("select_country", "Pais:",
                choices = items_country)
  })
  
observe({
    selected_range <- input$slide_range_date
    selected_country <- input$select_country
    
    if (!is.null(selected_range) & !is.null(selected_country)){
      total <- data_total %>% filter(as.Date(dates, "%Y-%m-%d") == selected_range & country == selected_country) %>% summarise(total = sum(value))
      death <- data_death %>% filter(as.Date(dates, "%Y-%m-%d") == selected_range & country == selected_country) %>% summarise(total = sum(value))
      recovered <- data_recovered %>% filter(as.Date(dates, "%Y-%m-%d") == selected_range & country == selected_country) %>% summarise(total = sum(value))
    }
    
    output$output_total <- renderValueBox({
      valueBox(
        formatC(total$total, format = "d", big.mark = ','),
        paste('Total de casos'),
        icon = icon("globe", lib = 'glyphicon'),
        color = "navy"
      )
      
    })
    
    output$output_death <- renderValueBox({
      valueBox(
        formatC(death$total, format = "d", big.mark = ','),
        paste('Muertes'),
        icon = icon("thumbs-down", lib = 'glyphicon'),
        color = "orange"
      )
      
    })
    
    output$output_recovered <- renderValueBox({
      valueBox(
        formatC(recovered$total, format = "d", big.mark = ','),
        paste('Recuperados'),
        icon = icon("thumbs-up", lib = 'glyphicon'),
        color = "aqua"
      )
      
    })
    
  })

data_plot <- reactive({
  selected_country <- input$select_country
  
  if (!is.null(selected_country)){
    data_plot_series <- data_total %>% filter(country == selected_country)
    
    columns_table <- data_plot_series %>% select(dates, value)
    
    output$render_data_table = DT::renderDataTable({
      
      datatable(columns_table) %>% formatStyle(
        'value',
        background = styleColorBar(range(columns_table$value), 'steelblue'),
        backgroundSize = '100% 90%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
      
    })
  }
  
  return(data_plot_series)
  
  })

 
 output$render_plot_daily <- renderPlot({
   
   ggplot(data_plot(), aes(x=as.Date(dates, "%Y-%m-%d")), size = 1.3) + 
     geom_line(aes(y=value), color="green") +
     labs(x="Fecha", y="Total de casos")
 })
  
    output$covid_map <- renderLeaflet({
        leaflet(data_total) %>% 
            setView(lng = -99, lat = 45, zoom = 2)  %>%
            addTiles() %>% 
            addCircles(data = data_total, lat = ~ lat, lng = ~ long, radius = ~sqrt(value)*300, weight = 1, label = ~as.character(paste0("Cantidad: ", sep = " ", value)), fillOpacity = 0.5)
    })

}
