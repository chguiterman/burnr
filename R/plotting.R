#' Create an ggplot2 object for plotting.
#'
#' @param x An \code{fhx} instance.
#' @param color_group Option to plot series with colors. This is a character vector or factor which corresponds to the series names given in \code{color_id}. Both \code{color_group} and \code{color_id} need to be specified. Default plot gives no color.
#' @param color_id Option to plot series with colors. A character vector of series names corresponding to groups given in \code{color_group}. Every unique value in \code{x} series.names needs to have a corresponding color_group value. Both \code{color_group} and \code{color_id} need to be specified. Default plot gives no species colors.
#' @param facet_group Option to plot series with faceted by a factor. A vector of factors or character vector which corresponds to the series names given in \code{facet_id}. Both \code{facet_group} and \code{facet_id} need to be specified. Default plot is not faceted.
#' @param facet_id Option to plot series with faceted by a factor. A vector of series names corresponding to species names given in \code{facet_group}. Every unique values in \code{x} series.names needs to have a corresponding facet_group value. Both \code{facet_group} and \code{facet_id} need to be specified.  Default plot is not faceted.
#' @param facet_type Type of \code{ggplot2} facet to use, if faceting. Must be either "grid" or "wrap". Default is "grid".
#' @param ylabels Optional boolean to remove y-axis (series name) labels and tick  marks. Default is TRUE.
#' @param yearlims Option to limit the plot to a range of years. This is a vector with two integers. The first integer gives the lower year for the range while the second integer gives the upper year. The default is to plot the full range of data given by \code{x}.
#' @param composite_rug A boolean option to plot a rug on the bottom of the plot. Default is FALSE.
#' @param filter_prop An optional argument if the user chooses to include a rug in their plot. This is passed to \code{composite}. See this function for details.
#' @param filter_min An optional argument if the user chooses to include a rug in their plot. This is passed to \code{composite}. See this function for details.
#' @param legend A boolean option allowing the user to choose whether a legend is included in the plot or not. Default is FALSE.
#' @param event_size An optional numeric vector that adjusts the size of fire event symbols on the plot. Default is \code{c("Scar" = 4, "Injury" = 2, "Pith/Bark" = 1.5)}.
#' @param rugbuffer_size An optional integer. If the user plots a rug, thiscontrols the amount of buffer whitespace along the y-axis between the rug and the main plot. Must be >= 2.
#' @param rugdivide_pos Optional integer if plotting a rug. Adjust the placement of the rug divider along the y-axis. Default is 2.
#' @return A ggplot object for plotting or manipulation.
get_ggplot <- function(x, color_group, color_id, facet_group, facet_id, facet_type="grid", ylabels=TRUE,
                       yearlims=FALSE, composite_rug=FALSE, filter_prop=0.25,
                       filter_min=2, legend=FALSE, event_size=c("Scar" = 4, "Injury" = 2, "Pith/Bark" = 1.5), 
                       rugbuffer_size=2, rugdivide_pos=2) {
# TODO: Merge ends and events into a single df. with a factor to handle the 
#       different event types... this will allow us to put these "fire events" and
#       "pith/bark" into a legend.
  stopifnot(facet_type %in% c("grid", "wrap"))
  stopifnot(rugbuffer_size >= 2)
  clean.nonrec <- subset(x$rings, x$rings$type != "recorder.year")
  scar.types <- c("unknown.fs", "dormant.fs", "early.fs",
                  "middle.fs", "late.fs", "latewd.fs")
  injury.types <- c("unknown.fi", "dormant.fi", "early.fi",
                    "middle.fi", "late.fi", "latewd.fi")
  pithbark.types <- c("pith.year", "bark.year")
  events <- subset(clean.nonrec, (type %in% scar.types) | (type %in% injury.types) | (type %in% pithbark.types))
  levels(events$type)[levels(events$type) %in% scar.types] <- "Scar"
  levels(events$type)[levels(events$type) %in% injury.types] <- "Injury"
  levels(events$type)[levels(events$type) %in% pithbark.types] <- "Pith/Bark"
  events$type <- factor(events$type, levels = c("Scar", "Injury", "Pith/Bark"))
  
  live <- aggregate(x$rings$year, by = list(x$rings$series), FUN = range, na.rm = TRUE)
  live <- data.frame(series = live$Group.1,
                     first = live$x[, 1],
                     last = live$x[, 2],
                     type = rep("non-recording", dim(live)[1]))
  recorder <- subset(x$rings, x$rings$type == "recorder.year")
  if ( dim(recorder)[1] > 0 ) {  # If there are recorder years...
    # Get the min and max of the recorder years.
    recorder <- aggregate(recorder$year,  # TODO: rename this var.
                           by = list(recorder$series, recorder$type),
                           FUN = range,
                           na.rm = TRUE)
    recorder <- data.frame(series = recorder$Group.1,
                           first = recorder$x[, 1],
                           last = recorder$x[, 2],
                           type = rep("recording", dim(recorder)[1]))
    segs <- rbind(recorder, live)
  } else {  # If there are no recorder years...
    segs <- live
  }
  levels(segs$type) <- c("Recording", "Non-recording")
  
  p <- NA
  rings <- x$rings
  if (!missing(facet_group) & !missing(facet_id)) {
    rings <- merge(rings, data.frame(series = facet_id, facet_group = facet_group), by = "series")
    segs <- merge(segs, data.frame(series = facet_id, facet_group = facet_group), by = "series")
    events <- merge(events, data.frame(series = facet_id, facet_group = facet_group),
                    by = "series")
  }
  if (missing(color_group) | missing(color_id)) {
    p <- ggplot2::ggplot(data = rings, ggplot2::aes(y = series, x = year))
  } else {
    rings <- merge(rings, data.frame(series = color_id, species = color_group), by = "series")
    segs <- merge(segs, data.frame(series = color_id, species = color_group), by = "series")
    events <- merge(events, data.frame(series = color_id, species = color_group),
                    by = "series")
    p <- ggplot2::ggplot(rings, ggplot2::aes(y = series, x = year, color = species))
  }
  p <- (p + ggplot2::geom_segment(ggplot2::aes(x = first, xend = last, y = series, yend = series, linetype = type),
                         data = segs)
          + ggplot2::scale_linetype_manual(values = c("solid", "dashed", "solid")))
          #+ ggplot2::scale_size_manual(values = c(0.5, 0.5, 0.3)))
  p <- (p + ggplot2::geom_point(data = events, ggplot2::aes(shape = type, size = type),
                       #size = event_size, color = "black")
                       color = "black")
          + ggplot2::scale_size_manual(values = event_size)
          + ggplot2::scale_shape_manual(guide = "legend",
                               values = c("Scar" = 124, "Injury" = 6, "Pith/Bark" = 20))) # `shape` 25 is empty triangles
  
  if (composite_rug) {
    p <- (p + ggplot2::geom_rug(data = subset(rings,
                                     rings$year %in% composite(x, 
                                                               filter_prop = filter_prop,
                                                               filter_min = filter_min)),
                       sides = "b", color = "black")
            + ggplot2::scale_y_discrete(limits = c(rep("", rugbuffer_size), levels(rings$series)))
            + ggplot2::geom_hline(yintercept = rugdivide_pos, color = "grey50"))
  }
  if (!missing(facet_group) & !missing(facet_id)) {
    if (facet_type == "grid") {
      p <- p + ggplot2::facet_grid(facet_group~., scales = "free_y", space = "free_y")
    }
    if (facet_type == "wrap") {
      p <- p + ggplot2::facet_wrap(~ facet_group, scales = "free_y")
    }
  }
  brks.major <- NA
  brks.minor <- NA
  yr.range <- diff(range(rings$year))
  if (yr.range < 100) {
      brks.major = seq(round(min(rings$year), -1),
                       round(max(rings$year), -1),
                       10)
      brks.minor = seq(round(min(rings$year), -1),
                       round(max(rings$year), -1),
                       5)
  } else if (yr.range >= 100) {
      brks.major = seq(round(min(rings$year), -2),
                       round(max(rings$year), -2),
                       100)
      brks.minor = seq(round(min(rings$year), -2),
                       round(max(rings$year), -2),
                       50)
  }
  p <- (p + ggplot2::scale_x_continuous(breaks = brks.major, minor_breaks = brks.minor)
          + ggplot2::theme_bw()
          + ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(),
                  panel.grid.minor.y = ggplot2::element_blank(),
                  axis.title.x = ggplot2::element_blank(),
                  axis.title.y = ggplot2::element_blank(),
                  legend.title = ggplot2::element_blank(),
                  legend.position = "bottom"))
  if (!legend) {
    p <- p + ggplot2::theme(legend.position = "none")
  }
  if (!missing(yearlims)) {
    p <- p + ggplot2::coord_cartesian(xlim = yearlims)
  }
  if (!ylabels) {
   p <- p + ggplot2::theme(axis.ticks = ggplot2::element_blank(), axis.text.y = ggplot2::element_blank())
  }
  p
}

#' Plot an fhx object.
#'
#' @param ... Arguments passed on to \code{get_ggplot}.
plot.fhx <- function(...) {
  print(get_ggplot(...))
}