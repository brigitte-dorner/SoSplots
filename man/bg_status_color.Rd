% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/setup.R
\name{bg_status_color}
\alias{bg_status_color}
\title{Status Colors for Plot Backgrounds}
\usage{
bg_status_color(status)
}
\arguments{
\item{status}{a character string that gives the status or status confidence;
valid status options are 'Green', 'AmberGreen', 'Amber', 'AmberRed', 'Red', 'DD'
valid status confidence options are 'High', 'Moderate', 'Low'
a default color is returned for unrecognized status values}
}
\value{
a string representing the status color in hex format
}
\description{
Generate a color value from a status color for shading plot background areas.
}
\examples{
status_color('Red', withAlpha = FALSE)
bg_status_color('Red')
}
