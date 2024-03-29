Ember.Handlebars.registerBoundHelper 'capitalize', (text) ->
  return null unless text?
  text.capitalize()

Ember.Handlebars.registerBoundHelper 'upcase', (text) ->
  return null unless text?
  text.toUpperCase()

Ember.Handlebars.registerBoundHelper 'humanize', (text) ->
  return null unless text?
  text.decamelize().replace(/[_-]/g, ' ').capitalize()

Ember.Handlebars.registerBoundHelper 'truncate', (text, options) ->
  return null unless text?
  text[0 ... options.hash.length ? 30]

Ember.Handlebars.registerBoundHelper 'emoticonize', (text, options) ->
  return null unless text?
  App.Emoticon.asHtml(text, classNames: 'small-emoticon')

# Returns given number of seconds formatted as a duration.
Ember.Handlebars.registerBoundHelper 'duration', (seconds) ->
  return null unless Ember.typeOf(seconds) == 'number'
  seconds = Math.round(seconds)
  duration = moment.duration(seconds, 'seconds')
  duration.humanize()

Ember.Handlebars.registerBoundHelper 'compact-timestamp-element', (date, options) ->
  return null unless date?
  now = new Date()
  m = moment.utc(date).local()
  daysDiff = m.diff(now, 'days', true)
  relativeTime = switch
    when daysDiff > -1 && m.date() == now.getDate()
      m.format('LT') # Just time.
    when daysDiff > -7
      m.format('dddd LT') # Day of week, e.g. Thursday.
    when daysDiff > -365
      # Try to strip off the year.
      m.format('M/D LT')
    else
      m.format('M/D/YY LT')
  tooltipTime = m.format('LLL')

  escape = Ember.Handlebars.Utils.escapeExpression
  classNames = options.hash.classNames
  if classNames
    classNames = classNames.join(' ') if Ember.typeOf(classNames) == 'array'
    attrs = " class='#{escape(classNames)}'"
  else
    attrs = ''

  "<span#{attrs} title='#{escape(tooltipTime)}'>#{escape(relativeTime)}</span>".htmlSafe()


# Copied and adapted from `textarea` helper from `ember.js/packages/ember-
# handlebars/lib/controls.js`
Ember.Handlebars.registerHelper 'actionable-textarea', (options) ->
  Ember.assert('You can only pass attributes to the `actionable-textarea` helper, not arguments', arguments.length < 2)

  hash = options.hash
  types = options.hashTypes

  Ember.Handlebars.helpers.view.call(@, App.ActionableTextareaComponent, options)


Ember.Handlebars.registerBoundHelper 'message-status-display', (message, options) ->
  # {{#if message.isSaving}}Sending...{{/if}}
  # {{#if message.isError}}
  #   <span class='error'>{{message.errorMessage}}</span>
  # {{/if}}
  buffer = []
  if message.get('isSaving')
    # Include trailing whitespace.
    buffer.push "Sending... "
  if message.get('isError')
    errorMessage = message.get('errorMessage') ? ''
    buffer.push "<span class='error'>"
    buffer.push Ember.Handlebars.Utils.escapeExpression(errorMessage)
    buffer.push "</span>"

  buffer.join('').htmlSafe()
, 'isSaving', 'isError', 'errorMessage'


Ember.Handlebars.registerBoundHelper 'message-attachment-display', (message, options) ->
  opts = options.hash

  message.attachmentDisplayHtml?(opts)


Ember.Handlebars.registerHelper 'webServerUrl', (path) ->
  App.webServerUrl(path)
