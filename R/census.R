#' function to get the census data
#' @param censusApiKey needs to be requested from https://api.census.gov/data/key_signup.html
#' @param year year of survey
#' @param dataset acs1 = annual; acs5 = 5-year rolling average
#'

getCensusMultiplier <- function(censusApiKey, year, dataset) {

  tidycensus::census_api_key(censusApiKey)

  x <- tidycensus::load_variables(year = 2020, dataset = "acs5")
  x <- x |>
    dplyr::filter(concept == "SEX BY AGE")

  x_name <- x$name

  census_us <- tidycensus::get_acs(geography = "US", year = 2020, variables = x_name)
  census_us <- census_us |>
    dplyr::left_join(x, by = c("variable" = "name"))

  n <- nrow(data.frame(age = unique(sub(".+!!(.+)", "\\1", census_us$label))) |>
              dplyr::filter( !age %in% c("Total:", "Male:", "Female:")
              ))

  standardizedAll <- census_us |>
    dplyr::mutate(age = sub(".+!!(.+)", "\\1", label),
                  sex = sub(".*!!([^:!!]*)\\:!!.*", "\\1", label)) |>
    dplyr::filter(
      !age %in% c("Total:", "Male:", "Female:")
    ) |>
    dplyr::group_by(sex) |>
    dplyr::mutate(
      multipler = estimate/sum(estimate)*n
    )

  multiplier <- tibble::tibble(
    age = rep(0:120, 2),
    sex = rep(c("Male", "Female"), each = 121),
    multiplier = c(
      rep(standardizedAll[1:3,]$multipler, each = 5), # 0-4, 5-9, 10-14,
      rep(standardizedAll[4,]$multipler, 3), # 15-17
      rep(standardizedAll[5,]$multipler, 2), # 18-19
      rep(standardizedAll[6:7,]$multipler, 1), # 20, 21
      rep(standardizedAll[8,]$multipler, 3), # 22-24
      rep(standardizedAll[9:15,]$multipler, 5), # 25-29, 30-34, 35-39, 40-44, 45-49, 50-54, 55-59
      rep(standardizedAll[16,]$multipler, 2), # 60-61
      rep(standardizedAll[17,]$multipler, 3), # 62-64
      rep(standardizedAll[18,]$multipler, 2), # 65-66
      rep(standardizedAll[19,]$multipler, 3), # 67-69
      rep(standardizedAll[20:22,]$multipler, 5), # 70-74, 75-79, 80-84
      rep(standardizedAll[23,]$multipler, 36), # 85-120
      rep(standardizedAll[24:26,]$multipler, each = 5), # 0-4, 5-9, 10-14,
      rep(standardizedAll[27,]$multipler, 3), # 15-17
      rep(standardizedAll[28,]$multipler, 2), # 18-19
      rep(standardizedAll[29:30,]$multipler, 1), # 20, 21
      rep(standardizedAll[31,]$multipler, 3), # 22-24
      rep(standardizedAll[32:38,]$multipler, 5), # 25-29, 30-34, 35-39, 40-44, 45-49, 50-54, 55-59
      rep(standardizedAll[39,]$multipler, 2), # 60-61
      rep(standardizedAll[40,]$multipler, 3), # 62-64
      rep(standardizedAll[41,]$multipler, 2), # 65-66
      rep(standardizedAll[42,]$multipler, 3), # 67-69
      rep(standardizedAll[43:45,]$multipler, 5), # 70-74, 75-79, 80-84
      rep(standardizedAll[46,]$multipler, 36) # 85-120
    )
  ) |>
    dplyr::mutate(gender_concept_id = dplyr::case_when(sex == "Male" ~ 8507,
                                                       sex == "Female" ~ 8532)) |>
    dplyr::select(age, gender_concept_id, multiplier)


  #saveRDS(object = multiplier, file = fs::path(outputFolder, "census_multipliers", ext = "rds"))

  return (multiplier)
}

createCensusReferenceTable <- function(executionSettings,
                                       connection,
                                       censusApiKey) {

  multiplier <- getCensusMultiplier(censusApiKey = censusApiKey)

  cli::cli_inform("STARTED: Creating census reference table")
  DatabaseConnector::insertTable(connection = connection,
                                 databaseSchema = executionSettings$workDatabaseSchema,
                                 tableName = "census_multipliers",
                                 data = multiplier,
                                 dropTableIfExists = TRUE,
                                 createTable = TRUE)
  cli::cli_inform("DONE: Creating census reference table")
}




