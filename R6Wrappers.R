#' @title Function for settings of prevalence analysis
#' @param targetCohort cohortIds for target
#' @param periodType annual or 5-year
#' @param studyWindow range of years of study
#' @param priorObservation days of washout period
#' @param weights census weights file

createPrevalenceAnalysis <- function(targetCohort,
                                     periodType,
                                     studyWindow,
                                     priorObservation,
                                     weights) {

  prevalenceAnalysis <- PrevalenceAnalysis$new(name = title,
                                               targetCohorts = targetCohorts,
                                               periodType = periodType,
                                               yearRange = yearRange,
                                               priorObservation = priorObservation,
                                               weights = weights)

  return(prevalenceAnalysis)

}
