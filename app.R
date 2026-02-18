# ---- Пакети ----
library(shiny)
library(shinythemes)
library(dplyr)
library(tidyr)
library(readxl)
library(recommenderlab)
library(purrr)
library(tibble)
library(openxlsx)
library(tools)
library(DT)
library(shinyjs)
library(shinycssloaders)


# >>> NEW: для KPI/карток (простий HTML)
library(htmltools)

# ---- UI ----
ui <- fluidPage(
  useShinyjs(),
  
  
  
  theme = shinytheme("flatly"),
  tags$head(
    tags$style(HTML("
      /* ===== ОСНОВНА ПАЛІТРА ===== */
      :root {
        --brand-main: #1B065E;
        --brand-accent: #D68FD6;
        --bg-light: #f7f8fa;
        --border-light: #e6e6ee;
      }
      body { background-color: var(--bg-light); color: #2b2b2b; }
      h1, h2, h3, h4, h5, h6 { color: var(--brand-main) !important; font-weight: 600; }
      a { color: var(--brand-main); }
      a:hover { color: var(--brand-accent); text-decoration: none; }

      .well-custom {
        background-color: #ffffff;
        border-radius: 10px;
        border: 1px solid var(--border-light);
        box-shadow: 0 4px 10px rgba(27,6,94,0.05);
        padding: 18px 22px;
        margin-bottom: 20px;
      }

      .btn-primary {
        background-color: var(--brand-main) !important;
        border-color: var(--brand-main) !important;
        color: #ffffff !important;
        font-weight: 500;
      }
      .btn-primary:hover { background-color: var(--brand-accent) !important; border-color: var(--brand-accent) !important; }

      .btn-success {
        background-color: var(--brand-accent) !important;
        border-color: var(--brand-accent) !important;
        color: #1B065E !important;
        font-weight: 500;
      }
      .btn-success:hover { background-color: #c87fc8 !important; border-color: #c87fc8 !important; }

      .download-btn { width: 100%; margin-bottom: 8px; }
      .nav-tabs > li > a { color: var(--brand-main); font-weight: 500; }
      .nav-tabs > li.active > a, .nav-tabs > li.active > a:hover {
        color: var(--brand-main); background-color: #ffffff; border-bottom: 3px solid var(--brand-accent);
      }

      .shiny-notification {
        background-color: #ffffff;
        color: var(--brand-main);
        border-left: 5px solid var(--brand-accent);
        box-shadow: 0 4px 10px rgba(0,0,0,0.08);
        font-size: 14px;
      }

      small, .help-block { color: #6b6b8a; }

      /* >>> NEW: KPI cards */
      .kpi-row { display: flex; gap: 12px; flex-wrap: wrap; }
      .kpi-card {
        flex: 1 1 170px;
        background: #fff;
        border: 1px solid var(--border-light);
        border-radius: 12px;
        padding: 14px 16px;
        box-shadow: 0 4px 10px rgba(27,6,94,0.05);
      }
      .kpi-title { font-size: 12px; color: #6b6b8a; margin-bottom: 6px; }
      .kpi-value { font-size: 22px; font-weight: 700; color: var(--brand-main); line-height: 1.1; }
      .kpi-sub { font-size: 12px; color: #6b6b8a; margin-top: 6px; }

      /* >>> NEW: step label */
      .step-badge {
        display: inline-block;
        font-size: 12px;
        padding: 3px 8px;
        border-radius: 999px;
        background: #F1D7F1;
        color: var(--brand-main);
        font-weight: 600;
        margin-right: 8px;
      }

      .hero-title { font-size: 20px; font-weight: 700; margin-bottom: 6px; }
      .hero-sub { color: #4f4f6f; margin-bottom: 10px; }
      .hero-bullets { margin: 0; padding-left: 18px; }
    "))
  ),
  
  div(
    id = "login_panel",
    class = "container",
    style = "max-width: 420px; margin-top: 120px;",
    wellPanel(
      h3("Вхід до додатку"),
      passwordInput("password", "Пароль"),
      actionButton("login", "Увійти", class = "btn-primary"),
      br(), br(),
      textOutput("login_msg")
    )
  ),
  
  hidden(
    div(
      id = "app_panel",
      
      titlePanel("Рекомендації категорій"),
      
      sidebarLayout(
        sidebarPanel(
          # >>> NEW: Value proposition + демо
          div(class = "well-custom",
              div(class = "hero-title", "Поради для CRM та крос-сейлу за категоріями"),
              div(class = "hero-sub",
                  "Швидко перетворює історію покупок у готові рекомендації для комунікацій (email/SMS/push) та сегментів."
              ),
              tags$ul(class = "hero-bullets",
                      tags$li("Готовий список рекомендацій по клієнтах"),
                      tags$li("Оцінка покриття та ТОП категорій"),
                      tags$li("Експорт у Excel для CRM")
              )
          ),
          
          # 1. Дані
          div(class = "well-custom",
              h4(tags$span(class="step-badge","Крок 1"), "Дані"),
              fileInput(
                "file",
                "Завантажте файл (xlsx/csv)",
                accept = c(".xlsx", ".xls", ".csv")
              ),
              # >>> NEW: шаблон
              downloadButton("download_template", "Скачати шаблон файлу", class = "btn btn-default btn-block"),
              br(),
              uiOutput("file_check_ui"),
              helpText(
                "Очікувані колонки у файлі:",
                tags$br(),
                tags$b("client_id"), " – ID клієнта;",
                tags$br(),
                tags$b("Категорія 2 рівня"), " – назва категорії."
              )
          ),
          
          # 2. Параметри
          div(class = "well-custom",
              h4(tags$span(class="step-badge","Крок 2"), "Налаштування"),
              numericInput("max_cats", "Скільки категорій беремо у модель (TOП найпопулярніших категорій)", value = 100, min = 10),
              br(), br(),
              numericInput("max_users", "Скільки клієнтів аналізуємо", value = 1000, min = 100),
              br(), br(),
              numericInput("top_n", "Скільки категорій рекомендувати кожному клієнту (максимальна кількість рекомендованих категорій)", value = 5, min = 1),
              br(), br(),
              actionButton("use_recommended", "Рекомендовані налаштування", class = "btn btn-default btn-block"),
              br(),
              actionButton("run", "Запустити модель", class = "btn btn-primary btn-block"),
              br(),
              
              div(
                id = "calc_status",
                style = "display:none; text-align:center; margin-top:10px;",
                tags$div(
                  tags$strong("Йде розрахунок…"),
                  br(),
                  tags$small("Будь ласка, зачекайте. Це може зайняти декілька хвилин в залежності від вибраної кількості клієнтів.")
                )
              )
              
          ),
          
          # 3. Експорт
          div(class = "well-custom",
              h4(tags$span(class="step-badge","Крок 3"), "Експорт результатів"),
              tags$small("Доступні після запуску моделі"),
              br(), br(),
              downloadButton("download_rank", "Рангові рекомендації (rank_matrix.xlsx)", class = "btn btn-success download-btn"),
              downloadButton("download_purchase", "Матриця 0/1 (client_category_matrix.xlsx)", class = "btn btn-default download-btn"),
              downloadButton("download_rec_list", "Список рекомендацій (recommendations_list.xlsx)", class = "btn btn-default download-btn"),
              downloadButton("download_combined", "Покупки 0/1 + рекомендації (combined.xlsx)", class = "btn btn-success download-btn"),
              downloadButton("download_profiles", "Профіль клієнтів (clients_profile.xlsx)", class = "btn btn-default download-btn"),
              downloadButton("download_penetration", "Охоплення категорій (category_penetration.xlsx)", class = "btn btn-default download-btn")
              # downloadButton("download_mono", "Mono-клієнти (mono_clients.xlsx)", class = "btn btn-default download-btn")
              
          ),
          width = 4
        ),
        
        mainPanel(
          tabsetPanel(
            tabPanel(
              "Огляд результатів",
              br(),
              # >>> NEW: KPI cards
              div(class = "well-custom",
                  h4("Результат запуску — коротко"),
                  uiOutput("kpi_cards")
              ),
              div(class = "well-custom",
                  h4("ТОП рекомендованих категорій"),
                  tableOutput("top_categories_all")
              ),
              div(class = "well-custom",
                  h4("Перегляд по клієнту: покупки vs рекомендації"),
                  uiOutput("client_picker_ui"),
                  br(),
                  tableOutput("client_view")
              )
            ),
            
            tabPanel(
              "Таблиця рекомендацій",
              br(),
              
              # ✅ НОВИЙ БЛОК ФІЛЬТРА
              div(class = "well-custom",
                  h4("Фільтр: клієнт купував обрані категорії (buy_*)"),
                  fluidRow(
                    column(
                      8,
                      selectizeInput(
                        "buy_multi_filter",
                        "Оберіть категорії (можна кілька)",
                        choices = NULL,
                        multiple = TRUE,
                        options = list(
                          placeholder = "Почніть вводити назву категорії…",
                          plugins = list("remove_button")
                        )
                      )
                    ),
                    column(
                      4,
                      radioButtons(
                        "buy_multi_mode",
                        "Умова",
                        choices = c("Усі обрані (AND)" = "AND", "Будь-яка з обраних (OR)" = "OR"),
                        inline = TRUE,
                        selected = "AND"
                      )
                    )
                  ),
                  tags$small("Порада: оберіть 2–4 категорії, щоб знайти “перетини” для сегмента/кампанії.")
              )
              ,
              
              # ✅ ТАБЛИЦЯ
              div(class = "well-custom",
                  h4("Покупки 0/1 + рекомендації — перегляд у додатку"),
                  tags$small("Зручно фільтрувати клієнтів за наявністю покупки конкретної категорії."),
                  br(), br(),
                  DTOutput("combined_table")
              ),
              
              # (залишаємо summary — воно корисне)
              div(class = "well-custom",
                  h4("Коротка інформація про запуск"),
                  verbatimTextOutput("summary")
              )
            )
            
            ,
            
            tabPanel(
              "Профіль клієнтів",
              br(),
              div(class="well-custom",
                  h4("KPI профілю клієнтів"),
                  uiOutput("kpi_profile_cards")
              ),
              div(class="well-custom",
                  h4("Розподіл кількості куплених категорій на клієнта"),
                  plotOutput("breadth_hist", height = 260)
              ),
              div(class="well-custom",
                  h4("Розподіл клієнтів за широтою кошика"),
                  plotOutput("breadth_groups_bar", height = 320)
                  
              ),
              div(class="well-custom",
                  h4("Таблиця профілю клієнтів"),
                  DTOutput("client_profile_table") %>% withSpinner()
              )
            ),
            
            tabPanel(
              "Охоплення категорій",
              br(),
              div(class="well-custom",
                  h4("ТОП-20 категорій за рівнем проникнення"),
                  tags$small("Рівень проникнення = % клієнтів, які купували категорію"),
                  br(), br(),
                  plotOutput("pen_bar", height = 320)
              ),
              div(class="well-custom",
                  h4("Таблиця охоплення"),
                  DTOutput("penetration_table") %>% withSpinner()
              ),
              
              
            ),
            
            
            tabPanel(
              "Про додаток",
              br(),
              div(class = "well-custom",
                  h3("Як працює інструмент рекомендацій"),
                  p("Додаток аналізує покупки клієнтів і пропонує категорії, які можуть бути релевантними."),
                  tags$ul(
                    tags$li("Файл перетворюється у матрицю клієнт × категорія (0/1)."),
                    tags$li("Беруться TOP-категорії за популярністю."),
                    tags$li("Будується модель UBCF з мірою Jaccard."),
                    tags$li("Формуються рекомендації для test-вибірки."),
                    tags$li("Доступні 4 файли експорту, включно з комбінованою таблицею.")
                  ),
                  tags$small("Ваші дані не зберігаються та використовуються лише для розрахунку.")
              )
            )
          )
        )
      )
    )
  )
)

# ---- SERVER ----
server <- function(input, output, session) {
  
  rv <- reactiveValues(
    # exports
    rank_matrix_export = NULL,
    purchase_dim = NULL,
    purchase_export = NULL,
    rec_list_export = NULL,
    combined_export = NULL,
    top_categories_all = NULL,
    top_categories_test = NULL,
    quality_summary = NULL,
    quality_details = NULL,
    
    # >>> NEW: dataset + per-client view
    df_raw = NULL,
    interactions = NULL,
    client_options = NULL,
    bad_rows = 0,
    bad_clients = 0,
    
    # >>> NEW: stage-1 analytics exports
    client_profile = NULL,
    penetration_tbl = NULL,
    mono_clients = NULL
    
  )
  
  # --- QUALITY HELPERS (holdout evaluation) ---
  calc_metrics_at_k <- function(recs, truth, k) {
    if (length(truth) == 0) {
      return(list(
        precision = NA_real_, recall = NA_real_,
        hit = NA_real_, ap = NA_real_, ndcg = NA_real_
      ))
    }
    
    recs <- recs[!is.na(recs) & recs != ""]
    if (length(recs) == 0) {
      return(list(precision = 0, recall = 0, hit = 0, ap = 0, ndcg = 0))
    }
    
    recs_k <- recs[seq_len(min(k, length(recs)))]
    hits <- recs_k %in% truth
    
    precision <- sum(hits) / k
    recall <- sum(hits) / length(truth)
    hitrate <- as.numeric(any(hits))
    
    # AP@K
    if (sum(hits) == 0) {
      ap <- 0
    } else {
      prec_at_i <- cumsum(hits) / seq_along(hits)
      ap <- sum(prec_at_i[hits]) / min(length(truth), k)
    }
    
    # nDCG@K (binary relevance)
    rel <- as.numeric(hits)
    dcg <- sum((2^rel - 1) / log2(seq_along(rel) + 1))
    ideal_rel <- c(rep(1, min(length(truth), k)), rep(0, k - min(length(truth), k)))
    idcg <- sum((2^ideal_rel - 1) / log2(seq_along(ideal_rel) + 1))
    ndcg <- ifelse(idcg == 0, 0, dcg / idcg)
    
    list(precision = precision, recall = recall, hit = hitrate, ap = ap, ndcg = ndcg)
  }
  
  make_holdout_newdata <- function(test_bin, keep_frac = 0.9, seed = 123) {
    set.seed(seed)
    m <- as(test_bin, "matrix")
    item_names <- colnames(m)
    
    n <- nrow(m)
    given_mat <- matrix(0, nrow = n, ncol = ncol(m))
    colnames(given_mat) <- item_names
    rownames(given_mat) <- rownames(m)
    
    truth_list <- vector("list", length = n)
    names(truth_list) <- rownames(m)
    
    keep_ids <- logical(n)
    
    for (i in seq_len(n)) {
      items <- which(m[i, ] > 0)
      if (length(items) < 2) {
        keep_ids[i] <- FALSE
        truth_list[[i]] <- character(0)
        next
      }
      
      given_n <- max(1, floor(length(items) * keep_frac))
      given <- sample(items, size = given_n)
      truth <- setdiff(items, given)
      
      if (length(truth) == 0) {
        keep_ids[i] <- FALSE
        truth_list[[i]] <- character(0)
        next
      }
      
      given_mat[i, given] <- 1
      truth_list[[i]] <- item_names[truth]
      keep_ids[i] <- TRUE
    }
    
    given_mat <- given_mat[keep_ids, , drop = FALSE]
    truth_list <- truth_list[keep_ids]
    
    newdata <- as(given_mat, "binaryRatingMatrix")
    list(newdata = newdata, truth = truth_list, given_mat = given_mat)
  }
  
  
  correct_password <- Sys.getenv("APP_PASS")
  
  observeEvent(input$login, {
    if (input$password == correct_password) {
      shinyjs::hide("login_panel")
      shinyjs::show("app_panel")
    } else {
      output$login_msg <- renderText("Невірний пароль")
    }
  })
  
  # >>> NEW: recommended settings button
  observeEvent(input$use_recommended, {
    updateNumericInput(session, "max_cats", value = 100)
    updateNumericInput(session, "max_users", value = 3000)
    updateNumericInput(session, "top_n", value = 5)
    showNotification("Встановлено рекомендовані налаштування ✅", type = "message")
  })
  
  # >>> NEW: download template
  output$download_template <- downloadHandler(
    filename = function() "template_client_category.xlsx",
    content = function(file) {
      tmp <- data.frame(
        client_id = c("C001","C001","C002","C003","C003"),
        `Категорія 2 рівня` = c("Coffee","Books","Tea","Books","Desserts"),
        check.names = FALSE
      )
      
      openxlsx::write.xlsx(tmp, file)
    }
  )
  
  observeEvent(rv$combined_export, {
    req(rv$combined_export)
    
    buy_cols <- grep("^buy_", names(rv$combined_export), value = TRUE)
    buy_names <- sub("^buy_", "", buy_cols)
    
    updateSelectizeInput(
      session,
      "buy_multi_filter",
      choices = buy_names,
      selected = character(0),
      server = TRUE
    )
  })
  
  
  
  # >>> NEW: demo data button
  observeEvent(input$use_demo, {
    set.seed(42)
    demo_clients <- sprintf("C%04d", 1:300)
    demo_cats <- c("Coffee","Tea","Books","Desserts","Sandwiches","Wine","Gifts","Kids","Stationery","Home","Beauty","Snacks")
    df_demo <- tibble(
      client_id = sample(demo_clients, 3500, replace = TRUE),
      `Категорія 2 рівня` = sample(demo_cats, 3500, replace = TRUE, prob = c(0.14,0.10,0.13,0.10,0.07,0.05,0.06,0.06,0.07,0.07,0.07,0.08))
    ) %>% distinct()
    rv$df_raw <- df_demo
    showNotification("Демо-дані завантажені ✅ Тепер натисніть «Запустити модель».", type = "message")
  })
  
  # >>> NEW: file reading + column check UI (doesn't run model)
  observeEvent(input$file, {
    req(input$file)
    ext <- tools::file_ext(input$file$name)
    if (ext %in% c("xlsx", "xls")) {
      df <- read_excel(input$file$datapath)
    } else if (ext == "csv") {
      df <- read.csv(input$file$datapath, stringsAsFactors = FALSE)
    } else {
      rv$df_raw <- NULL
      showNotification("Непідтримуваний формат файлу", type = "error")
      return(NULL)
    }
    
    # ---- Data quality check: empty categories ----
    if ("Категорія 2 рівня" %in% names(df)) {
      cat_raw <- as.character(df$`Категорія 2 рівня`)
      bad_mask <- is.na(cat_raw) | trimws(cat_raw) == ""
      rv$bad_rows <- sum(bad_mask)
      
      # скільки унікальних клієнтів мають хоч один "поганий" рядок
      if ("client_id" %in% names(df)) {
        rv$bad_clients <- dplyr::n_distinct(df$client_id[bad_mask])
      } else {
        rv$bad_clients <- 0
      }
    } else {
      rv$bad_rows <- 0
      rv$bad_clients <- 0
    }
    
    
    rv$df_raw <- df
  })
  
  output$file_check_ui <- renderUI({
    df <- rv$df_raw
    if (is.null(df)) return(NULL)
    
    needed_cols <- c("client_id", "Категорія 2 рівня")
    missing <- setdiff(needed_cols, colnames(df))
    found <- intersect(needed_cols, colnames(df))
    
    if (length(missing) > 0) {
      div(
        tags$small(tags$b("Перевірка файлу: "), style="color:#6b6b8a;"),
        tags$div(style="margin-top:6px;",
                 tags$span(style="color:#1B065E;font-weight:600;", "Знайдено: "),
                 paste(found, collapse = ", ")
        ),
        tags$div(style="margin-top:4px;color:#b00020;font-weight:600;",
                 "Не вистачає: ", paste(missing, collapse = ", ")
        )
      )
    } else {
      div(
        tags$div(style="color:#1f7a1f;font-weight:600;",
                 "✅ Файл коректний. Колонки знайдені: ", paste(needed_cols, collapse = ", ")
        ),
        tags$small("Можна запускати модель.")
      )
    }
  })
  
  # ---- RUN MODEL ----
  observeEvent(input$run, {
    
    disable("run")
    shinyjs::show("calc_status")
    
    withProgress(message = "Виконується розрахунок рекомендацій", value = 0, {
      
      incProgress(0.1, detail = "Перевірка та підготовка даних")
      
      # =========================
      # RULES / POLICY (MUST BE BEFORE predict/map2)
      # =========================
      
      never_recommend <- c(
        "женские гигиенические изделия",
        "средства интимной гигиены",
        "корм"
      )
      
      tobacco_cat <- c("сигареты")
      
      alcohol_cats <- c(
        "водка","виски","коньяк","бренди","вино тихое","вино игристое",
        "пиво","сидр","коктейли слабоалкогольные"
      )
      
      kids_signal <- c(
        "детские напитки",
        "сопутствующие товары детские",
        "детское питание"
      )
      
      kids_cat <- c(
        "детское питание",
        "детские напитки",
        "сопутствующие товары детские",
        "детские товары",
        "подгузники"
      )
      
      policy <- list(
        block_never_for_all = TRUE,
        block_tobacco_for_all = TRUE,
        allow_alcohol_only_if_bought_alcohol = TRUE,
        allow_kids_only_if_signal = TRUE,
        min_signal_count = 1
      )
      
      apply_rules <- function(recs, bought_items,
                              never_recommend, tobacco_cat, alcohol_cats,
                              kids_cat, kids_signal, policy) {
        
        recs <- recs[!is.na(recs) & recs != ""]
        recs <- setdiff(recs, bought_items)
        
        if (isTRUE(policy$block_never_for_all)) {
          recs <- setdiff(recs, never_recommend)
        }
        
        if (isTRUE(policy$block_tobacco_for_all)) {
          recs <- setdiff(recs, tobacco_cat)
        }
        
        if (isTRUE(policy$allow_kids_only_if_signal)) {
          has_kids_signal <- length(intersect(bought_items, kids_signal)) >= policy$min_signal_count
          if (!has_kids_signal) {
            recs <- setdiff(recs, kids_cat)
          }
        }
        
        if (isTRUE(policy$allow_alcohol_only_if_bought_alcohol)) {
          has_alcohol <- length(intersect(bought_items, alcohol_cats)) >= 1
          if (!has_alcohol) {
            recs <- setdiff(recs, alcohol_cats)
          }
        }
        
        recs
      }
      
      # >>> NEW: use either uploaded or demo data
      df <- rv$df_raw
      if (is.null(df)) {
        showNotification("Завантажте файл.", type = "error")
        return(NULL)
      }
      
      # ---- 1a. Перевірка колонок ----
      needed_cols <- c("client_id", "Категорія 2 рівня")
      missing <- setdiff(needed_cols, colnames(df))
      if (length(missing) > 0) {
        showNotification(
          paste0("У файлі не вистачає колонок: ", paste(missing, collapse = ", ")),
          type = "error"
        )
        return(NULL)
      }
      
      # Приводимо до стандартних назв
      # Приводимо до стандартної назви + чистимо текст категорій
      df <- df %>%
        mutate(
          category_lv2 = as.character(`Категорія 2 рівня`),
          category_lv2 = trimws(category_lv2),
          category_lv2 = gsub("\\s+", " ", category_lv2),
          category_lv2 = na_if(category_lv2, "")
        ) %>%
        filter(!is.na(category_lv2))
      
      
      # ---- 2. Взаємодії клієнт–категорія (0/1) ----
      # ---- 2. Взаємодії клієнт–категорія (0/1) ----
      interactions <- df %>%
        select(client_id, category_lv2) %>%
        distinct() %>%
        mutate(value = 1)
      
      rv$interactions <- interactions
      
      # === ВСТАВИТИ ОСЬ ТУТ (mono з сирих interactions) ===
      client_cat_counts_all <- interactions %>%
        count(client_id, name = "n_cat")
      
      n_clients_all <- dplyr::n_distinct(interactions$client_id)
      
      n_mono_clients_all <- client_cat_counts_all %>%
        filter(n_cat == 1) %>%
        nrow()
      
      share_mono_all <- round(100 * n_mono_clients_all / n_clients_all, 1)
      
      rv$share_mono_all <- share_mono_all
      
      rv$mono_clients <- interactions %>%
        inner_join(client_cat_counts_all, by = "client_id") %>%
        filter(n_cat == 1) %>%
        distinct(client_id, category_lv2) %>%
        rename(mono_category = category_lv2) %>%
        arrange(client_id)
      
      
      # ---- 3. Обмеження категорій до TOP-k ----
      cat_counts <- interactions %>%
        count(category_lv2, name = "n_clients") %>%
        arrange(desc(n_clients))
      
      
      
      
      max_cats <- input$max_cats
      if (nrow(cat_counts) > max_cats) {
        keep_cats <- cat_counts$category_lv2[1:max_cats]
        interactions <- interactions %>% filter(category_lv2 %in% keep_cats)
      }
      
      # ---- 4. Матриця клієнт × категорія (0/1) ----
      user_cat_matrix <- interactions %>%
        pivot_wider(names_from = category_lv2, values_from = value, values_fill = list(value = 0))
      
      client_ids <- user_cat_matrix$client_id
      purchase_matrix <- user_cat_matrix %>% select(-client_id) %>% as.matrix()
      
      
      
      # мінімум 2 покупки
      min_items_per_user <- 2
      keep_users <- rowSums(purchase_matrix > 0) >= min_items_per_user
      
      purchase_matrix <- purchase_matrix[keep_users, , drop = FALSE]
      client_ids <- client_ids[keep_users]          # <-- ОЦЕ ДОДАТИ
      
      # прибрати рідкі категорії
      min_users_per_item <- 5
      keep_items <- colSums(purchase_matrix > 0) >= min_users_per_item
      purchase_matrix <- purchase_matrix[, keep_items, drop = FALSE]
      
      rownames(purchase_matrix) <- client_ids       # тепер довжини співпадають
      
      
      # Обмеження по кількості клієнтів
      max_users <- input$max_users
      if (nrow(purchase_matrix) > max_users) {
        set.seed(123)
        idx <- sample(seq_len(nrow(purchase_matrix)), max_users)
        purchase_matrix <- purchase_matrix[idx, , drop = FALSE]
        client_ids <- client_ids[idx]                 # ✅ додали
        rownames(purchase_matrix) <- client_ids       # ✅ оновили
      }
      
      # =========================
      # STAGE 1: Client profile + penetration
      # =========================
      n_cat_total <- ncol(purchase_matrix)
      
      breadth <- rowSums(purchase_matrix > 0)
      
      breadth_group <- dplyr::case_when(
        breadth == 1 ~ "Mono (1)",
        breadth %in% 2:4 ~ "2–4",
        breadth %in% 5:9 ~ "5–9",
        breadth >= 10 ~ "10+",
        TRUE ~ "Zero (0)"
      )
      
      div_index <- if (n_cat_total > 0) breadth / n_cat_total else NA_real_
      
      # mono category (для mono клієнтів)
      
      
      client_profile <- data.frame(
        client_id = rownames(purchase_matrix),
        breadth = as.numeric(breadth),
        breadth_group = breadth_group,
        div_index = round(as.numeric(div_index), 4),
        stringsAsFactors = FALSE
      )
      rv$client_profile <- client_profile
      
      
      
      
      
      pen <- colMeans(purchase_matrix > 0)
      
      penetration_tbl <- tibble::tibble(
        Категорія = names(pen),
        `Рівень проникнення` = round(as.numeric(pen), 2),
        `Охоплення клієнтів, %` = round(100 * as.numeric(pen), 2),
        `К-сть клієнтів` = as.integer(colSums(purchase_matrix > 0))
      ) %>%
        dplyr::arrange(dplyr::desc(`Рівень проникнення`))
      
      
      
      # зберігаємо в rv
      rv$client_profile <- client_profile
      rv$penetration_tbl <- penetration_tbl
      
      
      
      storage.mode(purchase_matrix) <- "numeric"
      bin_mat <- as(purchase_matrix, "binaryRatingMatrix")
      
      # ---- 5. Train/Test split ----
      set.seed(123)
      n_users <- nrow(bin_mat)
      if (n_users < 5) {
        showNotification("Занадто мало клієнтів для побудови моделі.", type = "error")
        return(NULL)
      }
      
      train_id <- sample(seq_len(n_users), size = round(0.8 * n_users))
      train <- bin_mat[train_id, ]
      test  <- bin_mat[-train_id, ]
      
      # ---- 6. UBCF модель (Jaccard) ----
      # 1. Залишаємо модель для оцінки якості (на 80% даних)
      rec_val <- Recommender(train, "UBCF", parameter = list(method = "Jaccard", nn = 50))
      
      # 2. Створюємо фінальну модель для бізнесу (на 100% даних)
      # Саме вона дасть найкращі поради, бо знає історію кожного клієнта
      rec_final <- Recommender(bin_mat, "UBCF", parameter = list(method = "Jaccard", nn = 50))
      
      
      
      top_n <- input$top_n
      
      # ---- 6A. Рекомендації по TEST ----
      pred_test <- predict(rec_val, newdata = test, n = top_n, type = "topNList")
      rec_list_test <- as(pred_test, "list")
      test_ids <- rownames(test)
      
      test_m <- as(test, "matrix")
      
      rec_list_test <- purrr::map2(
        .x = rec_list_test,
        .y = test_ids,
        ~{
          uid <- .y
          bought_items <- colnames(test_m)[test_m[uid, ] > 0]
          
          head(
            apply_rules(
              recs = .x,
              bought_items = bought_items,
              never_recommend = never_recommend,
              tobacco_cat = tobacco_cat,
              alcohol_cats = alcohol_cats,
              kids_cat = kids_cat,
              kids_signal = kids_signal,
              policy = policy
            ),
            top_n
          )
        }
      )
      
      
      rec_long <- purrr::map2_df(
        .x = rec_list_test,
        .y = test_ids,
        ~ tibble::tibble(client_id = .y, category = .x, rank = seq_along(.x))
      )
      
      if (nrow(rec_long) == 0) {
        showNotification("Модель не згенерувала жодної рекомендації. Перевірте дані.", type = "error")
        return(NULL)
      }
      
      rec_long <- rec_long %>% mutate(rank_score = top_n - rank + 1)
      
      # ---- 7. ОЦІНКА ЯКОСТІ (тільки в лог/консоль, без UI) ----
      hold <- make_holdout_newdata(bin_mat, keep_frac = 0.7, seed = 123)
      
      
      if (nrow(hold$given_mat) >= 10) {
        
        # 7A) Predictions model (holdout newdata)
        pred_hold <- predict(rec_val, newdata = hold$newdata, n = top_n, type = "topNList")
        recs_list <- as(pred_hold, "list")
        user_ids <- rownames(hold$newdata)
        
        # 7B) Popular baseline: топ популярних категорій з train
        train_m <- as(train, "matrix")
        pop_counts <- colSums(train_m > 0)
        pop_items <- names(sort(pop_counts, decreasing = TRUE))
        
        make_pop_recs <- function(given_row, k) {
          already <- names(given_row)[given_row > 0]
          cand <- setdiff(pop_items, already)
          head(cand, k)
        }
        
        # 7C) Random baseline
        all_items <- colnames(hold$given_mat)
        make_rand_recs <- function(given_row, k) {
          already <- names(given_row)[given_row > 0]
          cand <- setdiff(all_items, already)
          if (length(cand) == 0) return(character(0))
          sample(cand, size = min(k, length(cand)))
        }
        
        # 7D) Метрики по клієнтах
        details <- purrr::map2_df(
          .x = user_ids,
          .y = seq_along(user_ids),
          ~{
            uid <- .x
            i <- .y
            
            given_row <- hold$given_mat[i, ]
            truth <- hold$truth[[uid]]
            
            rec_model <- recs_list[[i]]
            rec_pop <- make_pop_recs(given_row, top_n)
            rec_rand <- make_rand_recs(given_row, top_n)
            
            m1 <- calc_metrics_at_k(rec_model, truth, top_n)
            m2 <- calc_metrics_at_k(rec_pop, truth, top_n)
            m3 <- calc_metrics_at_k(rec_rand, truth, top_n)
            
            tibble::tibble(
              client_id = uid,
              truth_size = length(truth),
              
              model_precision = m1$precision,
              model_recall    = m1$recall,
              model_hit       = m1$hit,
              model_map       = m1$ap,
              model_ndcg      = m1$ndcg,
              
              pop_precision   = m2$precision,
              pop_recall      = m2$recall,
              pop_hit         = m2$hit,
              pop_map         = m2$ap,
              pop_ndcg        = m2$ndcg,
              
              rand_precision  = m3$precision,
              rand_recall     = m3$recall,
              rand_hit        = m3$hit,
              rand_map        = m3$ap,
              rand_ndcg       = m3$ndcg
            )
          }
        )
        
        summary_tbl <- tibble::tibble(
          Method = c("UBCF model", "Popular baseline", "Random baseline"),
          `Precision@K` = c(mean(details$model_precision, na.rm = TRUE),
                            mean(details$pop_precision,   na.rm = TRUE),
                            mean(details$rand_precision,  na.rm = TRUE)),
          `Recall@K`    = c(mean(details$model_recall, na.rm = TRUE),
                            mean(details$pop_recall,   na.rm = TRUE),
                            mean(details$rand_recall,  na.rm = TRUE)),
          `HitRate@K`   = c(mean(details$model_hit, na.rm = TRUE),
                            mean(details$pop_hit,   na.rm = TRUE),
                            mean(details$rand_hit,  na.rm = TRUE)),
          `MAP@K`       = c(mean(details$model_map, na.rm = TRUE),
                            mean(details$pop_map,   na.rm = TRUE),
                            mean(details$rand_map,  na.rm = TRUE)),
          `nDCG@K`      = c(mean(details$model_ndcg, na.rm = TRUE),
                            mean(details$pop_ndcg,   na.rm = TRUE),
                            mean(details$rand_ndcg,  na.rm = TRUE))
        ) %>%
          dplyr::mutate(
            `Precision@K` = round(`Precision@K`, 4),
            `Recall@K`    = round(`Recall@K`, 4),
            `HitRate@K`   = round(`HitRate@K`, 4),
            `MAP@K`       = round(`MAP@K`, 4),
            `nDCG@K`      = round(`nDCG@K`, 4)
          )
        
        # Збережемо в rv (на всяк випадок)
        rv$quality_summary <- summary_tbl
        rv$quality_details <- details
        
        # Вивід тільки в консоль / логи
        message("=== RECSYS QUALITY (Holdout on TEST) ===")
        message("K = ", top_n, ", holdout keep_frac = 0.7")
        print(summary_tbl)
        message("---- details (first 20 rows) ----")
        print(head(details, 20))
        message("=== END RECSYS QUALITY ===")
        
      } else {
        rv$quality_summary <- tibble::tibble(
          Message = "Not enough test users with >=2 purchases for holdout evaluation."
        )
        rv$quality_details <- NULL
        
        message("=== RECSYS QUALITY ===")
        message("Not enough test users with >=2 purchases for holdout evaluation.")
        message("=== END RECSYS QUALITY ===")
      }
      
      
      # ---- ТОП категорій по TEST (зрозумілий рейтинг для клієнта) ----
      n_test_clients <- rec_long %>% dplyr::summarise(n = dplyr::n_distinct(client_id)) %>% dplyr::pull(n)
      
      top_categories_test <- rec_long %>%
        dplyr::filter(!is.na(category), category != "", category != "OTHER") %>%
        dplyr::group_by(category) %>%
        dplyr::summarise(
          `Попит за рекомендаціями (індекс)` = sum(rank_score, na.rm = TRUE),
          `К-сть клієнтів, кому рекомендовано` = dplyr::n_distinct(client_id),
          `Середня сила рекомендації (1–N)` = round(mean(rank_score, na.rm = TRUE), 2),
          .groups = "drop"
        ) %>%
        dplyr::mutate(`Охоплення, % клієнтів` = round(100 * `К-сть клієнтів, кому рекомендовано` / n_test_clients, 1)) %>%
        dplyr::arrange(dplyr::desc(`Попит за рекомендаціями (індекс)`), dplyr::desc(`К-сть клієнтів, кому рекомендовано`)) %>%
        dplyr::slice_head(n = 20)
      
      rv$top_categories_test <- top_categories_test
      
      
      
      
      
      # ---- 6B. Рекомендації по ВСІХ ----
      # Використовуємо фінальну модель на повних даних
      # ---- 6B. Рекомендації по ВСІХ ----
      pred_all <- predict(rec_final, newdata = bin_mat, n = top_n, type = "topNList")
      rec_list_all <- as(pred_all, "list")
      all_ids <- rownames(bin_mat)
      
      # матриця покупок для визначення bought_items по кожному клієнту
      bin_m <- as(bin_mat, "matrix")
      
      rec_list_all <- purrr::map2(
        .x = rec_list_all,
        .y = all_ids,
        ~{
          uid <- .y
          bought_items <- colnames(bin_m)[bin_m[uid, ] > 0]
          
          out <- apply_rules(
            recs = .x,
            bought_items = bought_items,
            never_recommend = never_recommend,
            tobacco_cat = tobacco_cat,
            alcohol_cats = alcohol_cats,
            kids_cat = kids_cat,
            kids_signal = kids_signal,
            policy = policy
          )
          
          head(out, top_n)
        }
      )
      
      
      # важливо: якщо після фільтрації рекомендацій стало менше ніж top_n — це нормально.
      # але ти можеш не хотіти "порожніх" клієнтів, тоді:
      rec_list_all <- lapply(rec_list_all, function(x) head(x, top_n))
      
      
      rec_long_all <- purrr::map2_df(
        .x = rec_list_all,
        .y = all_ids,
        ~ tibble::tibble(client_id = .y, category = .x, rank = seq_along(.x))
      ) %>%
        mutate(rank_score = top_n - rank + 1)
      
      n_all_clients <- rec_long_all %>% dplyr::summarise(n = dplyr::n_distinct(client_id)) %>% dplyr::pull(n)
      
      top_categories_all <- rec_long_all %>%
        dplyr::filter(!is.na(category), category != "", category != "OTHER") %>%
        dplyr::group_by(category) %>%
        dplyr::summarise(
          `Індекс попиту` = sum(rank_score, na.rm = TRUE),
          `К-сть клієнтів, кому рекомендовано` = dplyr::n_distinct(client_id),
          `Середня сила рекомендації` = round(mean(rank_score, na.rm = TRUE), 2),
          .groups = "drop"
        ) %>%
        dplyr::mutate(`Охоплення, % клієнтів` = round(100 * `К-сть клієнтів, кому рекомендовано` / n_all_clients, 1)) %>%
        dplyr::arrange(dplyr::desc(`Індекс попиту`), dplyr::desc(`К-сть клієнтів, кому рекомендовано`)) %>%
        dplyr::slice_head(n = 20)
      
      rv$top_categories_all <- top_categories_all
      
      # ---- rank_matrix ----
      rank_matrix_export <- rec_long_all %>% 
        select(client_id, category, rank_score) %>%
        pivot_wider(names_from = category, values_from = rank_score, values_fill = 0) %>%
        as.data.frame()
      
      # ---- purchase_export (всі клієнти у матриці) ----
      purchase_export <- purchase_matrix %>% as.data.frame() %>% tibble::rownames_to_column("client_id")
      
      # ---- rec_list_export ----
      rec_list_export <- rec_long_all %>% arrange(client_id, rank) %>% select(client_id, category, rank_score)
      # ---- combined_export (тільки клієнти з рекомендаціями) ----
      # !!! НЕ ЧІПАЮ ЛОГІКУ - як у тебе
      recommended_ids <- unique(rec_long_all$client_id)
      
      purchase_matrix_recs <- purchase_matrix[rownames(purchase_matrix) %in% recommended_ids, , drop = FALSE]
      purchase_export_recs <- purchase_matrix_recs %>%
        as.data.frame() %>%
        tibble::rownames_to_column("client_id") %>%
        mutate(client_id = as.character(client_id)) %>%
        rename_with(~ paste0("buy_", .x), -client_id)
      
      rank_export_recs <- rank_matrix_export %>%
        mutate(client_id = as.character(client_id)) %>%
        filter(client_id %in% recommended_ids) %>%
        rename_with(~ paste0("rec_", .x), -client_id)
      
      combined_export <- purchase_export_recs %>% left_join(rank_export_recs, by = "client_id")
      
      # ---- Зберігаємо ----
      rv$rank_matrix_export <- rank_matrix_export
      rv$purchase_dim <- dim(purchase_matrix)
      rv$purchase_export <- purchase_export
      rv$rec_list_export <- rec_list_export
      rv$combined_export <- combined_export
      
      # >>> NEW: client dropdown options
      rv$client_options <- sort(unique(combined_export$client_id))
      
      
      
      
      showNotification("Розрахунок завершено ✅", type = "message")
      
      incProgress(1, detail = "Завершення")
    })
    
    
    
    shinyjs::hide("calc_status")
    enable("run")
    
  })
  
  # ---- OUTPUTS ----
  output$top_categories_all <- renderTable({
    req(rv$top_categories_all)
    rv$top_categories_all
  })
  
  output$top_categories_test <- renderTable({
    req(rv$top_categories_test)
    rv$top_categories_test
  })
  
  output$preview <- renderTable({
    req(rv$rank_matrix_export)
    head(rv$rank_matrix_export)
  })
  
  output$summary <- renderPrint({
    req(rv$rank_matrix_export, rv$purchase_dim, rv$combined_export)
    list(
      "Кількість клієнтів у матриці" = rv$purchase_dim[1],
      "Кількість категорій у матриці" = rv$purchase_dim[2],
      "Клієнтів з рекомендаціями (test)" = length(unique(rv$rank_matrix_export$client_id)),
      "Розмір рангової матриці (рядки × стовпці)" = dim(rv$rank_matrix_export),
      "Розмір combined (рядки × стовпці)" = dim(rv$combined_export)
      #"Порожніх категорій у вхідному файлі (рядків)" = rv$bad_rows %||% 0,
      #"Клієнтів з порожніми категоріями" = rv$bad_clients %||% 0
      
    )
  })
  
  # >>> NEW: KPI cards output
  output$kpi_cards <- renderUI({
    req(rv$purchase_dim, rv$combined_export, rv$top_categories_all)
    
    
    n_clients <- rv$purchase_dim[1]
    n_cats <- rv$purchase_dim[2]
    n_recommended <- nrow(rv$combined_export)
    coverage <- round(100 * n_recommended / n_clients, 1)
    bad_rows <- rv$bad_rows %||% 0
    bad_clients <- rv$bad_clients %||% 0
    
    
    # середня кількість рекомендацій (по rec_* з >0)
    rec_cols <- grep("^rec_", names(rv$combined_export), value = TRUE)
    avg_recs <- if (length(rec_cols) > 0) {
      mean(rowSums(rv$combined_export[, rec_cols, drop = FALSE] > 0))
    } else 0
    avg_recs <- round(avg_recs, 2)
    avg_breadth <- if (!is.null(rv$client_profile)) round(mean(rv$client_profile$breadth), 2) else NA
    
    
    div(class = "kpi-row",
        div(class = "kpi-card",
            div(class="kpi-title", "Клієнтів у моделі"),
            div(class="kpi-value", format(n_clients, big.mark=" ")),
            div(class="kpi-sub", paste0("Категорій: ", format(n_cats, big.mark=" ")))
        ),
        div(class = "kpi-card",
            div(class="kpi-title", "Клієнтів з рекомендаціями"),
            div(class="kpi-value", format(n_recommended, big.mark=" ")),
            div(class="kpi-sub", paste0("Покриття: ", coverage, "%"))
        ),
        div(class = "kpi-card",
            div(class="kpi-title", "Середня к-сть рекомендацій"),
            div(class="kpi-value", avg_recs)
        ),
        div(class = "kpi-card",
            div(class="kpi-title", "ТОП-1 категорія"),
            div(class="kpi-value", rv$top_categories_all$category[1] %||% "-"),
            div(class="kpi-sub", "за індексом попиту")
        ),
        div(class="kpi-card",
            div(class="kpi-title","Середня кількість категорій на клієнта"),
            div(class="kpi-value", avg_breadth),
            div(class="kpi-sub","широта портфеля категорій")
        )
        
        
        
    )
  })
  
  # >>> NEW: per-client view UI + table
  output$client_picker_ui <- renderUI({
    req(rv$client_options)
    selectInput("client_pick", "Оберіть клієнта", choices = rv$client_options, selected = rv$client_options[1])
  })
  
  output$client_view <- renderTable({
    req(rv$combined_export, input$client_pick)
    dfc <- rv$combined_export %>% filter(client_id == input$client_pick)
    
    buy_cols <- names(dfc)[startsWith(names(dfc), "buy_")]
    rec_cols <- names(dfc)[startsWith(names(dfc), "rec_")]
    
    bought <- tibble(
      type = "Покупки",
      category = sub("^buy_", "", buy_cols),
      value = as.numeric(dfc[1, buy_cols, drop = TRUE])
    ) %>% filter(value == 1) %>% select(type, category)
    
    recs <- tibble(
      type = "Рекомендації",
      category = sub("^rec_", "", rec_cols),
      score = as.numeric(dfc[1, rec_cols, drop = TRUE])
    ) %>% filter(score > 0) %>% arrange(desc(score)) %>% transmute(type, category)
    
    bind_rows(bought, recs)
  })
  
  output$kpi_profile_cards <- renderUI({
    req(rv$client_profile, rv$penetration_tbl)
    
    cp <- rv$client_profile
    
    avg_breadth <- round(mean(cp$breadth, na.rm = TRUE), 2)
    share_mono <- rv$share_mono_all %||% NA
    
    share_narrow <- round(100 * mean(cp$breadth >= 2 & cp$breadth <= 4, na.rm = TRUE), 1)
    share_medium <- round(100 * mean(cp$breadth >= 5 & cp$breadth <= 9, na.rm = TRUE), 1)
    share_broad <- round(100 * mean(cp$breadth >= 10, na.rm = TRUE), 1)
    
    div_avg <- round(mean(cp$div_index, na.rm = TRUE), 3)
    
    div(class="kpi-row",
        div(class="kpi-card",
            div(class="kpi-title","Середня кількість категорій на клієнта"),
            div(class="kpi-value", avg_breadth),
            div(class="kpi-sub","Глибина покупок")
        ),
        #div(class="kpi-card",
        #div(class="kpi-title","Mono-клієнти"),
        #div(class="kpi-value", paste0(share_mono, "%")),
        #div(class="kpi-sub","Клієнти з 1 категорією")
        #),
        div(class="kpi-card",
            div(class="kpi-title","Клієнти з 2-4 категоріями"),
            div(class="kpi-value", paste0(share_narrow, "%"))
        ),
        div(class="kpi-card",
            div(class="kpi-title","Клієнти з 5-9 категоріями"),
            div(class="kpi-value", paste0(share_medium, "%"))
        ),
        div(class="kpi-card",
            div(class="kpi-title","Клієнти з 10+ категоріями"),
            div(class="kpi-value", paste0(share_broad, "%")),
            div(class="kpi-sub","Клієнти з широким кошиком")
        ),
        div(class="kpi-card",
            div(class="kpi-title","Індекс диверсифікації покупок"),
            div(class="kpi-value", div_avg),
            div(class="kpi-sub","Середня частка категорій у кошику клієнта")
        )
    )
  })
  
  output$breadth_hist <- renderPlot({
    req(rv$client_profile)
    
    breadth_vals <- rv$client_profile$breadth
    
    freq_tbl <- table(breadth_vals)
    
    op <- par(no.readonly = TRUE)
    on.exit(par(op))
    
    par(mar = c(5, 5, 4, 2))  # красиві відступи
    
    barplot(
      freq_tbl,
      col = "#D68FD6",
      border = "#1B065E",
      xlab = "Кількість категорій",
      ylab = "Кількість клієнтів"
    )
  })
  
  
  output$client_profile_table <- renderDT({
    req(rv$client_profile)
    
    cp_ui <- rv$client_profile %>%
      dplyr::rename(
        `ID клієнта` = client_id,
        `К-сть категорій` = breadth,
        `Група за кількістю категорій` = breadth_group,
        `Індекс диверсифікації` = div_index
      )
    
    DT::datatable(cp_ui, rownames = FALSE, options = list(
      pageLength = 25, scrollX = TRUE
    ))
  })
  
  
  output$pen_bar <- renderPlot({
    req(rv$penetration_tbl)
    top <- head(rv$penetration_tbl, 20)
    
    # збільшуємо нижній відступ під підписи
    op <- par(no.readonly = TRUE)
    on.exit(par(op), add = TRUE)
    par(mar = c(11, 5, 3, 1))  # bottom, left, top, right
    
    bp <- barplot(
      top$`Охоплення клієнтів, %`,
      names.arg = rep("", nrow(top)),  # прибираємо стандартні підписи
      main = "ТОП-20 за рівнем проникнення",
      ylab = "% клієнтів"
    )
    
    # власні підписи під кутом 45°
    text(
      x = bp,
      y = par("usr")[3] - 0.5,  # трохи нижче осі
      labels = top$Категорія,
      srt = 45,
      adj = 1,
      xpd = TRUE,
      cex = 0.85
    )
  })
  
  output$breadth_groups_bar <- renderPlot({
    req(rv$client_profile)
    
    cp <- rv$client_profile
    
    validate(
      need(nrow(cp) > 0, "Немає даних профілю клієнтів (таблиця порожня).")
    )
    
    # 1) Безпечне витягування широти (breadth)
    if ("К-сть категорій" %in% names(cp)) {
      b <- cp[["К-сть категорій"]]
    } else if ("breadth" %in% names(cp)) {
      b <- cp[["breadth"]]
    } else {
      validate(need(FALSE, paste0(
        "Не знайдено колонку широти. Є колонки: ",
        paste(names(cp), collapse = ", ")
      )))
    }
    
    # 2) Привести до numeric (бо часто це стає character після data.frame/Excel)
    b <- suppressWarnings(as.numeric(b))
    
    validate(
      need(!all(is.na(b)), "Широта кошика (К-сть категорій) не є числовою або вся NA.")
    )
    
    # 3) Групи
    groups <- cut(
      b,
      breaks = c(1, 4, 9, Inf),
      labels = c("2–4", "5–9", "10+"),
      right = TRUE
    )
    
    cnt <- table(groups, useNA = "no")
    pct <- round(100 * prop.table(cnt), 1)
    
    validate(
      need(length(pct) > 0, "Після групування немає значень для побудови графіка."),
      need(is.finite(max(pct, na.rm = TRUE)), "Неможливо порахувати межі осі Y (pct містить NA/NaN).")
    )
    
    max_y <- max(pct, na.rm = TRUE)
    
    # 4) Малюємо
    op <- par(no.readonly = TRUE)
    on.exit(par(op), add = TRUE)
    par(mar = c(6, 5, 3, 1))
    
    bp <- barplot(
      pct,
      ylim = c(0, max_y * 1.2),
      main = "Розподіл клієнтів за широтою кошика",
      ylab = "Частка клієнтів, %",
      las = 1
    )
    
    text(bp, pct, labels = paste0(pct, "%"), pos = 3, cex = 0.9)
  })
  
  
  
  
  
  output$penetration_table <- renderDT({
    req(rv$penetration_tbl)
    DT::datatable(rv$penetration_tbl, rownames = FALSE, options = list(
      pageLength = 25, scrollX = TRUE
    ))
  })
  
  # ---- DOWNLOADS ----
  output$download_rank <- downloadHandler(
    filename = function() {
      base <- if (!is.null(input$file$name)) tools::file_path_sans_ext(input$file$name) else "demo"
      paste0("recommendations_rank_matrix_", base, ".xlsx")
    },
    content = function(file) {
      req(rv$rank_matrix_export)
      openxlsx::write.xlsx(rv$rank_matrix_export, file)
    }
  )
  
  output$download_purchase <- downloadHandler(
    filename = function() {
      base <- if (!is.null(input$file$name)) tools::file_path_sans_ext(input$file$name) else "demo"
      paste0("client_category_matrix_", base, ".xlsx")
    },
    content = function(file) {
      req(rv$purchase_export)
      openxlsx::write.xlsx(rv$purchase_export, file)
    }
  )
  
  output$download_rec_list <- downloadHandler(
    filename = function() {
      base <- if (!is.null(input$file$name)) tools::file_path_sans_ext(input$file$name) else "demo"
      paste0("recommendations_list_", base, ".xlsx")
    },
    content = function(file) {
      req(rv$rec_list_export)
      openxlsx::write.xlsx(rv$rec_list_export, file)
    }
  )
  
  output$combined_table <- renderDT({
    req(rv$combined_export)
    
    df <- rv$combined_export
    
    selected_cats <- input$buy_multi_filter
    mode <- input$buy_multi_mode %||% "AND"
    
    if (!is.null(selected_cats) && length(selected_cats) > 0) {
      cols <- paste0("buy_", selected_cats)
      cols <- cols[cols %in% names(df)]  # безпека
      
      if (length(cols) > 0) {
        mat <- as.matrix(df[, cols, drop = FALSE])
        
        keep <- if (mode == "AND") {
          rowSums(mat == 1) == ncol(mat)   # усі обрані = 1
        } else {
          rowSums(mat == 1) >= 1           # хоча б одна = 1
        }
        
        df <- df[keep, , drop = FALSE]
      }
    }
    
    buy_idx <- which(startsWith(names(df), "buy_"))
    rec_idx <- which(startsWith(names(df), "rec_"))
    client_idx <- which(names(df) == "client_id")
    
    dt <- DT::datatable(
      df,
      rownames = FALSE,
      extensions = c("Scroller"),
      options = list(
        scrollX = TRUE,
        scrollY = 520,
        scroller = TRUE,
        pageLength = 25,
        lengthMenu = c(10, 25, 50, 100),
        dom = "Blfrtip"
      )
    )
    
    # базове оформлення: покупки vs рекомендації
    if (length(buy_idx) > 0) {
      dt <- DT::formatStyle(
        dt,
        columns = buy_idx,
        backgroundColor = "#D9EEF9"  # як у твоєму Excel для buy_
      )
    }
    if (length(rec_idx) > 0) {
      dt <- DT::formatStyle(
        dt,
        columns = rec_idx,
        backgroundColor = "#F1D7F1"  # як у твоєму Excel для rec_
      )
    }
    
    # виділяємо client_id
    if (length(client_idx) > 0) {
      dt <- DT::formatStyle(
        dt,
        columns = client_idx,
        fontWeight = "700",
        backgroundColor = "#FFFFFF"
      )
    }
    
    dt
  })
  
  output$download_profiles <- downloadHandler(
    filename = function() {
      base <- if (!is.null(input$file$name)) tools::file_path_sans_ext(input$file$name) else "demo"
      paste0("clients_profile_", base, ".xlsx")
    },
    content = function(file) {
      req(rv$client_profile)
      cp_ui <- rv$client_profile %>%
        dplyr::rename(
          `ID клієнта` = client_id,
          `К-сть категорій` = breadth,
          `Група за кількістю категорій` = breadth_group,
          `Індекс диверсифікації` = div_index
        )
      
      openxlsx::write.xlsx(cp_ui, file)
      
    }
  )
  
  output$download_penetration <- downloadHandler(
    filename = function() {
      base <- if (!is.null(input$file$name)) tools::file_path_sans_ext(input$file$name) else "demo"
      paste0("category_penetration_", base, ".xlsx")
    },
    content = function(file) {
      req(rv$penetration_tbl)
      openxlsx::write.xlsx(rv$penetration_tbl, file)
    }
  )
  
  output$download_mono <- downloadHandler(
    filename = function() {
      base <- if (!is.null(input$file$name)) tools::file_path_sans_ext(input$file$name) else "demo"
      paste0("mono_clients_", base, ".xlsx")
    },
    content = function(file) {
      req(rv$mono_clients)
      openxlsx::write.xlsx(rv$mono_clients, file)
    }
  )
  
  
  
  
  
  
  # !!! download_combined — залишив твою логіку і форматування
  output$download_combined <- downloadHandler(
    filename = function() {
      base <- if (!is.null(input$file$name)) tools::file_path_sans_ext(input$file$name) else "demo"
      paste0("combined_purchases_and_recs_", base, ".xlsx")
    },
    content = function(file) {
      req(rv$combined_export)
      df_out <- rv$combined_export
      
      wb <- openxlsx::createWorkbook()
      openxlsx::addWorksheet(wb, "data")
      openxlsx::writeData(wb, "data", df_out)
      
      openxlsx::addWorksheet(wb, "read_me")
      readme_text <- c(
        "Як читати файл",
        "",
        "1) Колонки buy_* (покупки):",
        " • 1 — клієнт купував категорію",
        " • 0 — клієнт не купував категорію",
        "",
        "2) Колонки rec_* (рекомендації):",
        " • число > 0 — категорія рекомендована (чим більше, тим сильніша рекомендація)",
        " • 0 — категорія не рекомендована",
        "",
        "Примітка:",
        "Файл містить лише клієнтів, для яких модель згенерувала рекомендації."
      )
      openxlsx::writeData(wb, "read_me", data.frame(text = readme_text), colNames = FALSE)
      
      header_style <- openxlsx::createStyle(
        textDecoration = "bold",
        fgFill = "#1B065E",
        fontColour = "#FFFFFF",
        halign = "center",
        valign = "center",
        border = "Bottom"
      )
      
      openxlsx::addStyle(
        wb, "data", style = header_style,
        rows = 1, cols = 1:ncol(df_out),
        gridExpand = TRUE, stack = TRUE
      )
      
      buy_cols <- which(startsWith(names(df_out), "buy_"))
      rec_cols <- which(startsWith(names(df_out), "rec_"))
      buy_style <- openxlsx::createStyle(fgFill = "#D9EEF9")
      rec_style <- openxlsx::createStyle(fgFill = "#F1D7F1")
      
      if (length(buy_cols) > 0) {
        openxlsx::addStyle(
          wb, "data", style = buy_style,
          rows = 2:(nrow(df_out) + 1), cols = buy_cols,
          gridExpand = TRUE, stack = TRUE
        )
      }
      if (length(rec_cols) > 0) {
        openxlsx::addStyle(
          wb, "data", style = rec_style,
          rows = 2:(nrow(df_out) + 1), cols = rec_cols,
          gridExpand = TRUE, stack = TRUE
        )
      }
      
      openxlsx::freezePane(wb, "data", firstRow = TRUE)
      openxlsx::setColWidths(wb, "data", cols = 1:ncol(df_out), widths = "auto")
      openxlsx::setColWidths(wb, "read_me", cols = 1, widths = 70)
      openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
    }
  )
}

# helper for UI (safe null)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x)) y else x

# ---- Запуск додатку ----
shinyApp(ui, server)

