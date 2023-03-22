#  Code for generating plots used in the CU status summary panel
#  Adapted from Gottfried Pestal's SOS_RapidStatus_CaseStudies2022 code
#  https://github.com/SOLV-Code/SOS_RapidStatus_CaseStudies2022
#  Author: Brigitte Dorner
#  March 2023

require(graphics)
require(stats)

# -------------- define some defaults -------------------------

# status colors for drawing outline of cells in timeline plot
# color scheme borrowed from Gottfried's
outline_color <- function(status, alpha = 1) {
  switch(status,
         Red = 'firebrick1',
         RedAmber = 'firebrick1',
         Amber = 'orange',
         AmberGreen = 'green',
         Green = 'green',
         High = "darkblue",
         Moderate = "darkblue",
         Low = "darkblue",
         'darkgrey')
}

# status colors for drawing fill of cells in timeline plot
fill_color <- function(status) { status_color(status, withAlpha = F) }

# plot specs for metric plot
metricPlotSpecs.default <- list(main = list(cex.lab=1.2),                            # args passed to call to plot
                                x.axis = list(cex.axis=1.3),                         # x axis styling
                                y.axis = list(cex.axis=1.3),                         # y axis styling
                                hline = list(lty=2, cex=1.2, col='darkgrey'),        # styling for horizontal reference lines
                                hline.text = list(cex=1.2),                          # text styling for labels for horizontal ref lines
                                vline = list(lwd=2, lty=2, col='darkgrey'),          # styling for vertical reference lines
                                metric = list(type="o", col='darkblue', pch=19),     # styling for the metric time series line
                                av = list(type="l", col="red"),                      # styling for the moving generational average line
                                dom = list(type="p", col='darkblue', pch=21, bg='red', cex=1.3), # styling for dominant cycle year
                                title = list(cex=1.5, col.main='darkblue'))          # styling for the plot title

# plot specs for timeline plot
timelinePlotSpecs.default <- list(main = list(asp=1),                            # overall plot layout
                                  x.axis = list(cex.axis=1.5),                   # x axis styling
                                  title = list(font=2, col='darkblue', cex=1.5), # plot title styling
                                  label = list(cex=1.3, col='darkblue'),         # styling for metric series labels
                                  metric.text = list(col='darkblue', cex=1.5),   # styling for metric letter
                                  metric.line = list(col='darkgrey'))            # styling for metric square

# the metrics to plot in the timeline plot

# predefined here for use with the data frame returned by the Scanner's DataManager
# i.e., for use with the data frame returned by dataMngr$get_metricSeries_for_CU(CU_id)
timelineMetrics.default <- list(list(label = "RelAbd", dataCol = "RelLBM.Status"),
                                list(label = "AbsAbd", dataCol = "AbsLBM.Status"),
                                list(label = "LongTrend", dataCol = "LongTrend.Status"),
                                list(label = "PercChange", dataCol = "PercChange.Status"),
                                list(label = "RapidStatus" , dataCol = "RapidStatus.Status", font = 'bold'),
                                list(label = "ConfRating", dataCol = "RapidStatus.Confidence"),
                                list(label = "IntStatus", dataCol = "IntStatusRaw.Status"))

#-----------  Metric Plots -------------------

#' Generate a metric plot
#' with an optional running generational mean, color bands showing red, amber and green zones,
#' and optional additional horizontal and vertical reference lines
#' @param data the metric time series (a named vector, names should be years)
#' @param bmZones a list with entries Red and Amber, specifying the maximum values for each color zone
#' @param avGen   if provided, a running average spanning avGen years will be added to the plot
#' @param domCycleYear first dominant cycle year; if set, indicates that CU should be treated as cyclic,
#'                     which will result in values for dominant years being highlighted
#' @param hRefLines a list with entries of format label = y. If provided, additional reference lines
#'                  will be shown at each of the given y values, with associated labels appearing near the right margin
#' @param xRange an optional list with entries min and/or max;
#'                specifies the range of years to show on x axis; if min and/or max are specified,
#'                this will override min and max values taken from the data
#' @param xTickStep if specified, force the number of years between tickmarks on x axis
#' @param yRange range of values to show on the y axis, given as a vector with one or more elements
#' @param useLog if true, show data on log scale
#' @param plotTitle the plot title
#' @param tsName the label to use for the metric time series
#' @param vRefLines a number or vector. If provided, draw a vertical line at the corresponding years in the graph
#' @param gpar plot styling
#' @return generates a plot on the current graphics device
#' @export
metric_plot <- function(data, bmZones = NULL, avGen = NULL, domCycleYear = NULL, hRefLines = NULL, xRange = NULL, yRange = NULL, xTickStep = NULL,
                       useLog = FALSE, plotTitle = '', tsName = '', vRefLines = NULL, gpar = metricPlotSpecs.default) {

  # if there is no data, create an empty plot pane and then bail
  if (length(data) == 0 || all(is.na(data))) {
    graphics::plot.new()
    return()
  }

  # set plot margins
  graphics::par(mar = c(5,5,4,2))

  # get the plot dimensions and axis specs
  if (!is.null(bmZones)) {
    bmZones$Red <- ifelse(is.na(bmZones$Red) || bmZones$Red == 'NA', NA, as.numeric(bmZones$Red))
    bmZones$Amber <- ifelse(is.na(bmZones$Amber) || bmZones$Amber == 'NA', NA, as.numeric(bmZones$Amber))
  }

  ymax <- as_y(max(as.numeric(c(data, bmZones$Amber, hRefLines, yRange)), na.rm=T), useLog)
  ymin <- as_y(min(as.numeric(c(0, data, bmZones$Red, hRefLines, yRange)), na.rm=T), useLog)
  yaxis <- y_axis_specs(ymax, tsName, useLog)
  xRange <- pretty_range(xRange, as.numeric(names(data)), nearest = 5)

  # get the plot area set up - not actually plotting anything yet
  do.plot(fun = graphics::plot,
          args = list(x=xRange, type="n", xlim=xRange, ylim=c(ymin, ymax)/yaxis$scale, bty="n", xlab="Year", ylab=yaxis$label, axes=FALSE),
          override = gpar$main)

  # add x axis to the plot
  if (!is.null(xTickStep))
    args <- list(1, at=seq(xTickStep*ceiling(xRange[1]/xTickStep), xTickStep*floor(xRange[2]/xTickStep), by=xTickStep))
  else
    args <- list(1)
  do.plot(fun = graphics::axis, args = args, override = gpar$x.axis)

  # add y axis to the plot
  if (useLog) {
    yTicks <- log_ticks(ymax)
    args <- list(2, at = yTicks, labels=names(yTicks))
  }
  else
    args <- list(2)
  do.plot(fun = graphics::axis, args = args, override = gpar$y.axis)

  # add shaded rectangular areas to plot background, corresponding to red, amber and green status zones
  if (!is.null(bmZones) && !is.na(bmZones$Red) && !is.na(bmZones$Amber)) {
    yLower <- as_y(bmZones$Red, useLog)/yaxis$scale
    yUpper <- as_y(bmZones$Amber, useLog)/yaxis$scale
    xLeft <- graphics::par("usr")[1]
    xRight <- graphics::par("usr")[2]
    yTop <- graphics::par("usr")[4]
    yBottom <- graphics::par("usr")[3]
    graphics::rect(xLeft, yUpper, xRight, yTop, col= bg_status_color('Green'), border = bg_status_color('Green'))
    graphics::rect(xLeft, yLower, xRight, yUpper, col= bg_status_color('Amber'), border = bg_status_color('Amber'))
    graphics::rect(xLeft, yLower, xRight, yBottom, col= bg_status_color('Red'), border = bg_status_color('Red'))
  }

  # add horizontal reference lines to the plot
  for (lab in names(hRefLines)) {
    if (!is.na(hRefLines[[lab]])) {
      do.plot(fun = graphics::abline, args = list(h = hRefLines[[lab]]),override = gpar$hline)
      do.plot(fun = graphics::text, args = list(x=graphics::par("usr")[2], y=hRefLines[[lab]], labels=lab, font=1, adj=c(1,0), xpd=NA), override = gpar$hline.text)
    }
  }

  # add vertical reference lines to the plot
  for (i in 1:length(vRefLines)) {
    if(!is.na(vRefLines[i]))
      do.plot(fun = graphics::abline, args = list(v = vRefLines[i]), override = gpar$vline)
  }

  # add the metric time series to the plot
  yrs <- as.numeric(names(data))
  ts <- as_y(data, useLog)/yaxis$scale
  do.plot(fun = graphics::lines, args = list(x = yrs, y = ts), override = gpar$metric)

  # add a running average
  if (!is.null(avGen))
    do.plot(fun = graphics::lines, args = list(x = yrs, y = running_mean(ts, as.numeric(avGen))), override = gpar$av)

  # highlight dominant cycle years
  if (!is.null(domCycleYear)) {
    domYrs <- yrs[yrs %in% seq(domCycleYear, max(yrs), by = 4)]
    do.plot(fun=graphics::lines, args=list(x=domYrs, y=as_y(data[as.character(domYrs)], useLog)/yaxis$scale), override=gpar$dom)
  }

  # add plot title
  do.plot(fun = graphics::title, args = list(main = plotTitle, line = 1), override = gpar$title)
}


#-----------  Relative Abundance Plot -------------------

#' Generate a Relative Abundance Plot
#' with color bands showing red, amber and green zones for the Relative Abundance metric
#' @param data the Absolute Abundance time series (a named vector, names should be years)
#' @param attribs a list with CU attributes LBM and UBM, the lower and upper benchmark respectively
#'                if AvGen is provided, a running generational average will be added
#'                if DomCycleYear is provided, values for dominant cycle years will be highlighted
#' @param yrRange range of years to show on x axis, given as a list with optional entries ming and/or max, i.e.
#'                yrRange = list(min=<start year>, max=<end year>)
#' @param gpar plot styling
#' @return generates a plot on the current graphics device
#' @export
#'
RelAbd_plot <- function(data, attribs, yrRange = NULL, gpar = metricPlotSpecs.default) {
  domYr <- get_dom_cycle_yr(attribs)
  avGen <- NULL
  if(is.null(domYr)) avGen <- get_av_gen(attribs)
  metric_plot(data = data, bmZones = list(Red = attribs$RelAbd_LBM, Amber = attribs$RelAbd_UBM),
              avGen = avGen, domCycleYear = domYr,
              xRange = yrRange, yRange = c(0), xTickStep = 5,
              plotTitle = 'Relative Abundance Metric', tsName = 'Wild Spn')
}

#-----------  Relative Abundance Index Plot - log plot of full TS -------------------

#' Generate a Relative Abundance Plot (log scale)
#' @param data the Absolute Abundance time series (a named vector, names should be years)
#' @param attribs a list with CU attributes
#'                if AvGen is provided, a running generational average will be added
#'                if Cyclic is set and DomCycleYear is provided, values for dominant cycle years will be highlighted
#' @param yrRange range of years to show on x axis, given as a list with optional entries ming and/or max, i.e.
#'                yrRange = list(min=<start year>, max=<end year>)
#' @param gpar plot styling
#' @return generates a plot on the current graphics device
#' @export
#'
LogRelAbd_plot <- function(data, attribs, yrRange = NULL, gpar = metricPlotSpecs.default) {
  # Note: no color bands here
  domYr <- get_dom_cycle_yr(attribs)
  avGen <- NULL
  if(is.null(domYr)) avGen <- get_av_gen(attribs)
  metric_plot(data = data, bmZones = NULL,
              avGen = avGen, domCycleYear = domYr,
              xRange = yrRange, useLog = TRUE, plotTitle = 'Relative Index of Abundance (Log Scale)', tsName = 'Wild Spn')
}

#-----------  Absolute Abundance Plot -------------------

#' Generate an Absolute Abundance Plot (log scale)
#' with color bands showing red, amber and green zones for the Absolute Abundance metric
#' @param data the Absolute Abundance time series (a named vector, names should be years)
#' @param attribs a list with CU attributes LBM and UBM, the lower and upper benchmark respectively
#'                if AvGen is provided, a running generational average will be added
#'                if DomCycleYear is provided, values for dominant cycle years will be highlighted
#' @param yrRange range of years to show on x axis, given as a list with optional entries ming and/or max, i.e.
#'                yrRange = list(min=<start year>, max=<end year>)
#' @param gpar plot styling
#' @return generates a plot on the current graphics device
#' @export
#'
LogAbsAbd_plot <- function(data, attribs, yrRange = NULL, gpar = metricPlotSpecs.default) {
  domYr <- get_dom_cycle_yr(attribs)
  avGen <- NULL
  if(is.null(domYr)) avGen <- get_av_gen(attribs)
  metric_plot(data = data, bmZones = list(Red = attribs$AbsAbd_LBM, Amber = attribs$AbsAbd_UBM),
              avGen = avGen, domCycleYear = domYr, hRefLines = NULL, xRange = yrRange,
              useLog = TRUE, plotTitle = 'Absolute Abundance Metric (Log Scale)', tsName = 'Wild Spn', gpar = gpar)
}

#-----------  Long-term Trend Plot -------------------

#' Generate a Long-term Trend Plot
#' with color bands showing red, amber and green zones, and reference lines
#' @param data the long-term trend time series (a named vector, names should be years)
#' @param attribs a list with CU attributes LBM and UBM, the lower and upper benchmark respectively
#'                if AvGen is provided, a running generational average will be added
#'                if DomCycleYear is provided, values for dominant cycle years will be highlighted
#' @param yrRange range of years to show on x axis, given as a list with optional entries ming and/or max, i.e.
#'                yrRange = list(min=<start year>, max=<end year>)
#' @param gpar plot styling
#' @return generates a plot on the current graphics device
#' @export
#'
LongTrend_plot <- function(data, attribs, yrRange = NULL, gpar = metricPlotSpecs.default) {
  hRefLines = list('3/4' = as.numeric(attribs$LongTrend_UBM),
                   'Half' = as.numeric(attribs$LongTrend_LBM),
                   'Same' = 1,
                   'Double' = 2)
  data <- data / 100
  metric_plot(data = data, bmZones = list(Red = attribs$LongTrend_LBM, Amber = attribs$LongTrend_UBM),
              avGen = NULL, domCycleYear = NULL, hRefLines = hRefLines, xRange = yrRange,
              plotTitle = 'Long-term Trend Metric', tsName = 'Ratio(Current/Long-term)', gpar = gpar)
}

#-----------  Percent Change Plot -------------------

#' Generate a Percent Change Plot
#' with color bands showing red, amber and green zones, and reference lines
#' @param data the percent change time series (a named vector, names should be years)
#' @param attribs a list with CU attributes LBM and UBM, the lower and upper benchmark respectively
#'                if AvGen is provided, a running generational average will be added
#'                if DomCycleYear is provided, values for dominant cycle years will be highlighted
#' @param yrRange range of years to show on x axis, given as a list with optional entries ming and/or max, i.e.
#'                yrRange = list(min=<start year>, max=<end year>)
#' @param gpar plot styling
#' @return generates a plot on the current graphics device
#' @export
#'
PercChange_plot <- function(data, attribs, yrRange = NULL, gpar = metricPlotSpecs.default) {
  hRefLines = list('Half' = -50, 'Same' = 0, 'Double' = 100)
  metric_plot(data = data, bmZones = list(Red = attribs$PercChange_LBM, Amber = attribs$PercChange_UBM),
              avGen = NULL, domCycleYear = NULL, hRefLines = hRefLines, xRange = yrRange, yRange = c(-55, 50),
              plotTitle = 'Percent Change Metric', tsName = '% Change - 3 Gen', gpar = gpar)
}

#-----------  Timeline Plot -------------------

#' Plot a set of time series using a series of squares, with letters and colouring indicating status (or confidence in status)
#' @param data a data frame containing the metrics to plot. Metrics should be in columns.
#'              data must also contain a 'Year' column, to be used as the x-axis values.
#' @param metrics a list of lists specifying the metrics to plot. At a minimum, each entry in metrics must specify
#'                 a label attribute and a dataCol attribute, where dataCol provides the column name of the metric in data.
#'                 If a font attribute is provided, it overrides the default font.
#'                 Font options are 'plain' (the default), 'bold', 'italic', 'bold italic'.
#'                 Note: the font set here is used to select one of the fonts set via par('font'),
#'                 following the convention that font #1 corresponds to plain text, font #2 to bold etc.
#'                 See par documentation for details. Font can also be specified more directly by giving the numeric index.
#' @param title the plot title (optional)
#' @param startYr optional: if provided, the first year to show in the timeline
#' @param endYr optional: if provided the final year to show in the timeline
#' @param gpar plot styling
#' @return generates a plot on the current graphics device
#' @export
#'
timeline_plot <- function(data, metrics = timelineMetrics.default, title = "Metrics & Status", startYr = NULL, endYr = NULL, gpar = timelinePlotSpecs.default) {

  # plot setup
  stopifnot('Year' %in% names(data))
  graphics::par(mar=c(2, 7, 5, 2)) # plot margins

  if (is.null(startYr))
    startYr <- min(as.numeric(data$Year))
  if (is.null(endYr))
    endYr <- max(as.numeric(pretty(data$Year)))
  # get the plot area set up - no plotting yet
  xlim <- c(startYr, endYr)
  ylim <- c(-length(metrics) - 0.3, 0)
  do.plot(fun = graphics::plot,
          args = list(x = 1:5, y = 1:5, type = "n", xlim = xlim, ylim = ylim, xlab = "", ylab = "", axes = FALSE),
          override = gpar$main)

  # add x axis
  do.plot(fun = graphics::axis,
          args = list(3, at = pretty(data$Year), pos=0),
          override = gpar$x.axis)

  # add plot title
  do.plot(fun = graphics::mtext,
          args = list(title, side = 3, line = 3, xpd = NA),
          override = gpar$title)

  # add the metrics
  for(i in 1:length(metrics)){
    font <- get_font(metrics[[i]]$font)
    gpar$metric.text$font <- font
    # plot the time series label
    do.plot(fun = graphics::text,
            args = list(x=graphics::par("usr")[1], y=-i, labels=metrics[[i]]$label, adj=c(1), xpd=NA, font=font),
            override = gpar$label)

    # draw the timeline
    if (metrics[[i]]$dataCol %in% colnames(data))
      draw_metric_row(y=-i, m=get_ts(metrics[[i]]$dataCol, data),  startYr=xlim[1], endYr=xlim[2], gpar=gpar)
  }
}

# ------------- multi-panel CU Metric Summary Pane ----------

#' CU metrics summary pane
#' @param CUmetrics a data frame with CU metrics in columns; at a minimum, should contain a Year column
#'                  plus the columns specified in timelineMetrics
#' @param  CUts     a data frame with spawner abundance time series; at a minimum, should contain columns
#'                  Year, SpnForAbd_Wild
#' @param  CUattribs a list of attributes; at a minimum, should contain the following fields
#'                  CU_Name: the name of the CU
#'                  RelAbd_LBM, RelAbd_UBM, AbsAbd_LBM, AbsAbd_UBM, LongTrend_LBM, LongTrend_UBM, PercChange_LBM, PercChange_UBM: upper and lower benchmarks for the status metrics
#'                  AvGen: average generation length
#'                  domCycleYear: the first dominant cycle year if the CU is cyclic
#'                  DataQualkIdx: 'AbsAbd' if the SpnForAbd_Wild time series has absolute abundance values
#'                                'Rel.Idx' if the SpnForAbd_Wild time series is an index time series
#' @param metricStartYr optional: first year to show metrics for in timeline plot; also marked with a vertical reference line in the metric plots.
#' @param metricEndYr optional: final year to show metrics for in the metric plots; use this for consistent styling. Has no effect on timeline plot.
#' @param metricPlotSpecs optional:
#'                        layout options for the metrics plots
#'                        see metricPlotSpecs.default for details
#' @param timelineMetricSpecs optional:
#'                            If NULL, no timeline metrics are plotted.
#'                            If provided, timelineMetricSpecs should be a list of lists,
#'                            where each entry specifies one metric to include in the timeline plot
#'                            entries are specified as lists, containing a label and dataCol,
#'                            where dataCol is the name of the corresponding column in the CUmetrics data frame
#'                            and label is the label to show on the plot
#'                            the list may also contain a font attribute, which, if specified, overrides the default
#'                            the predefined timelineMetrics.default structure contains the necessary definitions for working
#'                            with the data frame provided by the Scanner's DataManager module via get_metricSeries_for_CU(CU_id)
#' @param timelinePlotSpecs optional:
#'                        layout options for the timeline plots
#'                        see timelinePlotSpecs.default for details
#' @return generates a plot on the current graphics device
#' @export
#'
metric_summary_pane <- function(CUmetrics, CUts, CUattribs,
                                metricStartYr = NULL,
                                metricEndYr = NULL,
                                metricPlotSpecs = metricPlotSpecs.default,
                                timelineMetricSpecs = timelineMetrics.default,
                                timelinePlotSpecs = timelinePlotSpecs.default) {

  if (is.null(metricEndYr)) metricEndYr <- 5*ceiling(max(as.numeric(CUmetrics$Year))/5)
  if (is.null(metricStartYr)) metricStartYr <- 5*floor(min(as.numeric(CUmetrics$Year))/5)

  if (!is.null(timelineMetricSpecs)) # add timeline plot to bottom of panel
    graphics::layout(mat=matrix(c(1,2,3,4,5,5), ncol=2, byrow=TRUE), heights = c(1,1,1,1))
  else
    graphics::layout(mat=matrix(c(1,2,3,4), ncol=2, byrow=TRUE), heights = c(1,1))
  graphics::par(oma=c(0, 0, 5, 0)) # plot margins - add space on top for title

  # abundance time series and metrics plots, arranged as a 2x2 matrix
  RelAbd_plot(data=get_ts('Escapement_Wild', CUts), attribs=CUattribs, yrRange=list(max=metricEndYr), gpar=metricPlotSpecs)
  if (!is.na(CUattribs$DataQualkIdx) && CUattribs$DataQualkIdx == 'Abs_Abd')
    LogAbsAbd_plot(data=get_ts('Escapement_Wild', CUts), attribs=CUattribs, yrRange=list(max=metricEndYr), gpar=metricPlotSpecs)
  else
    LogRelAbd_plot(data=get_ts('Escapement_Wild', CUts), attribs=CUattribs, yrRange=list(max=metricEndYr), gpar=metricPlotSpecs)

  LongTrend_plot(data=get_ts('LongTrend', CUmetrics), attribs=CUattribs, yrRange=list(max=metricEndYr), gpar=metricPlotSpecs)
  PercChange_plot(data=get_ts('PercChange', CUmetrics), attribs=CUattribs, yrRange=list(max=metricEndYr), gpar=metricPlotSpecs)

  # add a timeline plot below, spanning the full width of the page
  if (!is.null(timelineMetricSpecs))
    timeline_plot(CUmetrics, metrics=timelineMetricSpecs, title="Metrics & Status", gpar=timelinePlotSpecs, startYr=metricStartYr)

  graphics::title(main = paste0(CUattribs$CU_Name, " (Data = ", CUattribs$DataQualkIdx, ")"), cex.main=2, col.main="darkblue", outer=TRUE)
}