#' Slider Input Widget
#'
#' Constructs a slider widget to select a number, date, or date-time from a
#' range.
#'
#' @inheritParams textInput
#' @param min,max The minimum and maximum values (inclusive) that can be
#'   selected.
#' @param value The initial value of the slider, either a number, a date
#'   (class Date), or a date-time (class POSIXt). A length one vector will
#'   create a regular slider; a length two vector will create a double-ended
#'   range slider. Must lie between `min` and `max`.
#' @param step Specifies the interval between each selectable value on the
#'   slider. Either `NULL`, the default, which uses a heuristic to determine the
#'   step size or a single number. If the values are dates, `step` is in days;
#'   if the values are date-times, `step` is in seconds.
#' @param round `TRUE` to round all values to the nearest integer;
#'   `FALSE` if no rounding is desired; or an integer to round to that
#'   number of digits (for example, 1 will round to the nearest 10, and -2 will
#'   round to the nearest .01). Any rounding will be applied after snapping to
#'   the nearest step.
#' @param ticks `FALSE` to hide tick marks, `TRUE` to show them
#'   according to some simple heuristics.
#' @param animate `TRUE` to show simple animation controls with default
#'   settings; `FALSE` not to; or a custom settings list, such as those
#'   created using [animationOptions()].
#' @param sep Separator between thousands places in numbers.
#' @param pre A prefix string to put in front of the value.
#' @param post A suffix string to put after the value.
#' @param dragRange This option is used only if it is a range slider (with two
#'   values). If `TRUE` (the default), the range can be dragged. In other
#'   words, the min and max can be dragged together. If `FALSE`, the range
#'   cannot be dragged.
#' @param timeFormat Only used if the values are Date or POSIXt objects. A time
#'   format string, to be passed to the Javascript strftime library. See
#'   <https://github.com/samsonjs/strftime> for more details. The allowed
#'   format specifications are very similar, but not identical, to those for R's
#'   [base::strftime()] function. For Dates, the default is `"%F"`
#'   (like `"2015-07-01"`), and for POSIXt, the default is `"%F %T"`
#'   (like `"2015-07-01 15:32:10"`).
#' @param timezone Only used if the values are POSIXt objects. A string
#'   specifying the time zone offset for the displayed times, in the format
#'   `"+HHMM"` or `"-HHMM"`. If `NULL` (the default), times will
#'   be displayed in the browser's time zone. The value `"+0000"` will
#'   result in UTC time.
#' @inheritParams selectizeInput
#' @family input elements
#' @seealso [updateSliderInput()]
#'
#' @examples
#' ## Only run examples in interactive R sessions
#' if (interactive()) {
#' options(device.ask.default = FALSE)
#'
#' ui <- fluidPage(
#'   sliderInput("obs", "Number of observations:",
#'     min = 0, max = 1000, value = 500
#'   ),
#'   plotOutput("distPlot")
#' )
#'
#' # Server logic
#' server <- function(input, output) {
#'   output$distPlot <- renderPlot({
#'     hist(rnorm(input$obs))
#'   })
#' }
#'
#' # Complete app with UI and server components
#' shinyApp(ui, server)
#' }
#'
#' @section Server value:
#' A number, date, or date-time (depending on the class of `value`), or
#' in the case of slider range, a vector of two numbers/dates/date-times.
#'
#' @export
sliderInput <- function(inputId, label, min, max, value, step = NULL,
                        round = FALSE, ticks = TRUE, animate = FALSE,
                        width = NULL, sep = ",", pre = NULL, post = NULL,
                        timeFormat = NULL, timezone = NULL, dragRange = TRUE) {
  #validate_slider_value(min, max, value, "sliderInput")

  dataType <- getSliderType(min, max, value)

  if (is.null(timeFormat)) {
    timeFormat <- switch(dataType, date = "%F", datetime = "%F %T", number = NULL)
  }

  # Restore bookmarked values here, after doing the type checking, because the
  # restored value will be a character vector instead of Date or POSIXct, and we can do
  # the conversion to correct type next.
  value <- restoreInput(id = inputId, default = value)

  if (is.character(value)) {
    # If we got here, the value was restored from a URL-encoded bookmark.
    if (dataType == "date") {
      value <- as.Date(value, format = "%Y-%m-%d")
    } else if (dataType == "datetime") {
      # Date-times will have a format like "2018-02-28T03:46:26Z"
      value <- as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    }
  }

  step <- findStepSize(min, max, step)

  if (dataType %in% c("date", "datetime")) {
    # For Dates, this conversion uses midnight on that date in UTC
    to_ms <- function(x) 1000 * as.numeric(as.POSIXct(x))

    # Convert values to milliseconds since epoch (this is the value JS uses)
    # Find step size in ms
    step  <- to_ms(max) - to_ms(max - step)
    min   <- to_ms(min)
    max   <- to_ms(max)
    value <- to_ms(value)
  }

  range <- max - min

  # Try to get a sane number of tick marks
  if (ticks) {
    n_steps <- range / step

    # Make sure there are <= 10 steps.
    # n_ticks can be a noninteger, which is good when the range is not an
    # integer multiple of the step size, e.g., min=1, max=10, step=4
    scale_factor <- ceiling(n_steps / 10)
    n_ticks <- n_steps / scale_factor

  } else {
    n_ticks <- NULL
  }

  sliderProps <- dropNulls(list(
    class = "js-range-slider",
    id = inputId,
    `data-skin` = "shiny",
    `data-type` = if (length(value) > 1) "double",
    `data-min` = formatNoSci(min),
    `data-max` = formatNoSci(max),
    `data-from` = formatNoSci(value[1]),
    `data-to` = if (length(value) > 1) formatNoSci(value[2]),
    `data-step` = formatNoSci(step),
    `data-grid` = ticks,
    `data-grid-num` = n_ticks,
    `data-grid-snap` = FALSE,
    `data-prettify-separator` = sep,
    `data-prettify-enabled` = (sep != ""),
    `data-prefix` = pre,
    `data-postfix` = post,
    `data-keyboard` = TRUE,
    # This value is only relevant for range sliders; for non-range sliders it
    # causes problems since ion.RangeSlider 2.1.2 (issue #1605).
    `data-drag-interval` = if (length(value) > 1) dragRange,
    # The following are ignored by the ion.rangeSlider, but are used by Shiny.
    `data-data-type` = dataType,
    `data-time-format` = timeFormat,
    `data-timezone` = timezone
  ))

  # Replace any TRUE and FALSE with "true" and "false"
  sliderProps <- lapply(sliderProps, function(x) {
    if (identical(x, TRUE)) "true"
    else if (identical(x, FALSE)) "false"
    else x
  })

  sliderTag <- div(class = "form-group shiny-input-container",
    style = css(width = validateCssUnit(width)),
    shinyInputLabel(inputId, label),
    do.call(tags$input, sliderProps)
  )

  # Add animation buttons
  if (identical(animate, TRUE))
    animate <- animationOptions()

  if (!is.null(animate) && !identical(animate, FALSE)) {
    if (is.null(animate$playButton))
      animate$playButton <- icon('play', lib = 'glyphicon')
    if (is.null(animate$pauseButton))
      animate$pauseButton <- icon('pause', lib = 'glyphicon')

    sliderTag <- tagAppendChild(
      sliderTag,
      tags$div(class='slider-animate-container',
        tags$a(href='#',
          class='slider-animate-button',
          'data-target-id'=inputId,
          'data-interval'=animate$interval,
          'data-loop'=animate$loop,
          span(class = 'play', animate$playButton),
          span(class = 'pause', animate$pauseButton)
        )
      )
    )
  }

  attachDependencies(sliderTag, ionRangeSliderDependency())
}


ionRangeSliderDependency <- function() {
  list(
    # ion.rangeSlider also needs normalize.css, which is already included in Bootstrap.
    htmlDependency(
      "ionrangeslider-javascript",
      version_ion_range_slider,
      src = "www/shared/ionrangeslider",
      package = "shiny",
      script = "js/ion.rangeSlider.min.js"
    ),
    htmlDependency(
      "strftime",
      version_strftime,
      src = "www/shared/strftime",
      package = "shiny",
      script = "strftime-min.js"
    ),
    bslib::bs_dependency_defer(ionRangeSliderDependencyCSS)
  )
}

ionRangeSliderDependencyCSS <- function(theme) {
  if (!is_bs_theme(theme)) {
    return()
    return(htmlDependency(
      "ionrangeslider-css",
      version_ion_range_slider,
      src = "www/shared/ionrangeslider",
      package = "shiny",
      stylesheet = "css/ion.rangeSlider.css"
    ))
  }

  bslib::bs_dependency(
    input = list(
      list(accent = "$component-active-bg"),
      sass::sass_file(
        system_file(package = "shiny", "www/shared/ionrangeslider/scss/shiny.scss")
      )
    ),
    theme = theme,
    name = "ionRangeSlider",
    version = version_ion_range_slider,
    cache_key_extra = get_package_version("shiny")
  )
}

hasDecimals <- function(value) {
  truncatedValue <- round(value)
  return (!identical(value, truncatedValue))
}

# If step is NULL, use heuristic to set the step size.
findStepSize <- function(min, max, step) {
  if (!is.null(step)) return(step)

  range <- max - min
  # If short range or decimals, use continuous decimal with ~100 points
  if (range < 2 || hasDecimals(min) || hasDecimals(max)) {
    # Workaround for rounding errors (#1006): the intervals between the items
    # returned by pretty() can have rounding errors. To avoid this, we'll use
    # pretty() to find the min, max, and number of steps, and then use those
    # values to calculate the step size.
    pretty_steps <- pretty(c(min, max), n = 100)
    n_steps <- length(pretty_steps) - 1

    # Fix for #2061: Windows has low-significance digits (like 17 digits out)
    # even at the boundaries of pretty()'s output. Use signif(digits = 10),
    # which should be way way less significant than any data we'd want to keep.
    # It might make sense to use signif(steps[2] - steps[1], 10) instead, but
    # for now trying to make the minimal change.
    signif(digits = 10, (max(pretty_steps) - min(pretty_steps)) / n_steps)

  } else {
    1
  }
}

# Throw a warning if ever `value` is not in the [`min`, `max`] range
validate_slider_value <- function(min, max, value, fun) {
  if (length(min)   != 1 || is_na(min) ||
      length(max)   != 1 || is_na(max) ||
      length(value) <  1 || length(value) > 2 || any(is.na(value)))
  {
    stop(call. = FALSE,
      sprintf("In %s(): `min`, `max`, and `value` cannot be NULL, NA, or empty.", fun)
    )
  }

  if (min(value) < min) {
    warning(call. = FALSE,
      sprintf(
        "In %s(): `value` should be greater than or equal to `min` (value = %s, min = %s).",
        fun, paste(value, collapse = ", "), min
      )
    )
  }

  if (max(value) > max) {
    warning(
      noBreaks. = TRUE, call. = FALSE,
      sprintf(
        "In %s(): `value` should be less than or equal to `max` (value = %s, max = %s).",
        fun, paste(value, collapse = ", "), max
      )
    )
  }
}


#' @rdname sliderInput
#'
#' @param interval The interval, in milliseconds, between each animation step.
#' @param loop `TRUE` to automatically restart the animation when it
#'   reaches the end.
#' @param playButton Specifies the appearance of the play button. Valid values
#'   are a one-element character vector (for a simple text label), an HTML tag
#'   or list of tags (using [tag()] and friends), or raw HTML (using
#'   [HTML()]).
#' @param pauseButton Similar to `playButton`, but for the pause button.
#' @export
animationOptions <- function(interval=1000,
                             loop=FALSE,
                             playButton=NULL,
                             pauseButton=NULL) {
  list(interval=interval,
       loop=loop,
       playButton=playButton,
       pauseButton=pauseButton)
}
