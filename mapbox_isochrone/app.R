library(shiny)
library(leaflet)
library(mapboxapi)
library(mapdeck)
library(waiter)
library(fontawesome)
mb_access_token(token = Sys.getenv("MAPBOX_TOKEN"), install = FALSE)

# UI ----------------------------------------------------------------------
ui <- fluidPage(
    titlePanel("行けるかな?地図"),
    use_waitress(),
    
    sidebarLayout(
        sidebarPanel(
            p("任意の地点からの到達可能な領域を表示します。下のフォームに対象の地点名または住所を入力し、決定ボタンを押してください。
      オプションとして、交通手段の変更が可能です。"),
            p("表示される領域は、目安として5、15、30、60分以内で到達可能な領域です。"),
            tags$form(
                textInput("geocoding_location",
                          label = tags$p("任意の地点名を入力してください", 
                                         fa("search", fill = "black")),
                          value = "東京駅"),
                radioButtons("travel_mode",
                                    label = "交通手段",
                                    choices = c("徒歩" = "walking", 
                                                "自転車" = "cycling", 
                                                "自動車" = "driving"),
                                    selected = "徒歩",
                                    inline = TRUE),
                actionButton("submit", "決定"),
                tags$br(),
                tags$p(fa("twitter", fill = "black"), 
                       tags$a(href = "https://twitter.com/uribo", "u_ribo"),
                       align = "right"),
                tags$p(fa("github", fill = "black"),
                       tags$a(href = "https://github.com/uribo/shinyapps/blob/master/mapbox_isochrone/app.R", 
                              "ソースコードを見る"),
                       align = "right")
                )
        ),
        mainPanel(
            mapdeckOutput("md", height = 600)
        )
    )
)


# Server ------------------------------------------------------------------
server <- function(input, output, session) {
    waitress <- Waitress$new(theme = "overlay-percent")
    observeEvent(input$submit, {
        waitress$auto(value = 5, ms = 150)
        Sys.sleep(3.5)
        waitress$close()
    })
    geo_data <- eventReactive(input$submit, {
        geocode_res <-
            mapboxapi::mb_geocode(input$geocoding_location,
                                  language = "ja",
                                  limit = 1)
        if (!is.null(geocode_res)) {
            coords <-
                as.list(geocode_res %>% 
                            purrr::set_names(c("x", "y")))
            isochrone <-
             mb_isochrone(location = geocode_res,
                           profile = input$travel_mode,
                          denoise = 0,
                          keep_color_cols = TRUE,
                           time = c(5, 15, 30, 60))
            zoom <-
                dplyr::case_when(
                    input$travel_mode == "walking" ~ 16,
                    input$travel_mode == "cycling" ~ 14,
                    input$travel_mode == "driving" ~ 10)
            return(list(coords = coords, 
                        isochrone = isochrone,
                        zoom = zoom))
        }
    })
    output$md <- renderMapdeck({
        mapdeck(location = c(geo_data()$coords$x, 
                             geo_data()$coords$y),
                zoom = as.numeric(geo_data()$zoom)) %>%
            add_polygon(data = geo_data()$isochrone,
                        fill_colour = "time",
                        fill_opacity = 0.5,
                        legend = TRUE)
    })
}

shinyApp(ui, server)
