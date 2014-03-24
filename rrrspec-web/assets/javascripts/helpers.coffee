formatDate = (date)->
  if date
    moment(date).format("YYYY-MM-DD HH:mm:ss z")
  else
    ""

formatDuration = (start, finish)->
  moment.duration(moment(finish).diff(moment(start))).humanize()

formatDateWithDuration = (date, start)->
  if date && start
    "#{formatDate(date)} (#{formatDuration(start, date)})"
  else if date
    "#{formatDate(date)}"
  else
    ""

Handlebars.registerHelper('date', formatDate)
Handlebars.registerHelper('duration', formatDuration)
Handlebars.registerHelper('dateWithDuration', formatDateWithDuration)
