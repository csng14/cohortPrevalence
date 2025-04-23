#' function to instantiate calendar years into the db as a sql script
#'
.initiateCalendarYears <- function(years = 2011:2024, tableName = "#year_interval", executionSettings) {
  tb <- tibble::tibble(
    calendar_year = years
  )
  sql <- ClinicalCharacteristics:::.insertTableSql(
    executionSettings = executionSettings,
    tableName = tableName,
    data = tb
  )
  return(sql)
}


generateCohortPrevalence <- function(executionSettings,
                                     targetCohort,
                                     yearRange = 2011:2024,
                                     priorObservation = 365,
                                     weights = NULL) {

  # get year table sql
  yearRangeSql <- .initiateCalendarYears(years = yearRange, executionSettings = executionSettings)

  prevSql <- fs::path("analysis/src/sql/prevalence.sql") |>
    readr::read_file() |>
    SqlRender::render(
      cdm_database_schema = executionSettings$cdmDatabaseSchema,
      vocabulary_database_schema = executionSettings$cdmDatabaseSchema,
      work_database_schema = executionSettings$workDatabaseSchema,
      cohort_table = executionSettings$targetCohortTable,
      washout_period = priorObservation,
      target_cohort_id = targetCohort$cohortId
    ) |>
    SqlRender::translate(
      targetDialect = executionSettings$getDbms(),
      tempEmulationSchema = executionSettings$tempEmulationSchema
    )

  allSql <- c(yearRangeSql, prevSql) |>
    glue::glue_collapse("\n\n")


  cli::cat_bullet(
    "Generate Prevalence",
    bullet = "pointer",
    bullet_col = "yellow"
  )

  if (is.null(executionSettings$getConnection())) {
    executionSettings$connect()
  }

  DatabaseConnector::executeSql(
    connection = executionSettings$getConnection(),
    sql = allSql
  )

  getPrevSql <- "SELECT * FROM #prev_summary;" |>
    SqlRender::translate(
      targetDialect = executionSettings$getDbms(),
      tempEmulationSchema = executionSettings$tempEmulationSchema
    )

  tb <- DatabaseConnector::querySql(
    connection = executionSettings$getConnection(),
    sql = getPrevSql,
    snakeCaseToCamelCase = TRUE
  )

  executionSettings$disconnect()

  savePath <- fs::path(outputFolder, "prevalence.csv")

  cli::cat_bullet(
    glue::glue_col("Save prevalence to {cyan {savePath}}"),
    bullet = "pointer",
    bullet_col = "yellow"
  )
  readr::write_csv(
    x = tb,
    file = savePath
  )

  return(tb)
}
