# Substitutes emoticons into user text.
Ember.Handlebars.registerBoundHelper 'evalMessageText', (text) ->

  escapedText = Ember.Handlebars.Utils.escapeExpression(text)

  # Link to URLs.
  urlRegexp = ///
    \b(https?|ftp)://[-A-Za-z0-9+&@\#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@\#/%=~_()|]
  ///g
  escapedText = escapedText.replace urlRegexp, (fullMatch) ->
    "<a href='#{fullMatch}' target='_blank'>#{fullMatch}</a>"

  # Emoticons.
  evaledText = App.Emoticon.all().reduce (str, emoticon) ->
    regexp = new RegExp(App.Util.escapeRegexp(emoticon.get('name')), 'g')
    imageHtml = "<img src='#{emoticon.get('imageUrl')}' title='#{emoticon.get('name')}'>"
    str.replace regexp, imageHtml
  , escapedText

  evaledText.htmlSafe()


Ember.Handlebars.registerBoundHelper 'compactTimestampElement', (date) ->
  return null unless date?
  now = new Date()
  m = moment.utc(date).local()
  daysDiff = m.diff(now, 'days', true)
  relativeTime = switch
    when daysDiff > -1
      m.format('LT') # Just time.
    when daysDiff > -7
      m.format('dddd LT') # Day of week, e.g. Thursday.
    when daysDiff > -365
      # Try to strip off the year.
      m.format('M/D LT')
    else
      m.format('M/D/YY LT')
  tooltipTime = m.format('LLL')

  new Handlebars.SafeString("<span title='#{Handlebars.Utils.escapeExpression(tooltipTime)}'>#{Handlebars.Utils.escapeExpression(relativeTime)}</span>")


# This converts named arguments that are unquoted to bindings.
normalizeHash = (hash, hashTypes) ->
  for prop of hash
    if hashTypes[prop] == 'ID'
      hash[prop + 'Binding'] = hash[prop]
      delete hash[prop]

# Copied and adapted from `textarea` helper from `ember.js/packages/ember-
# handlebars/lib/controls.js`
Ember.Handlebars.registerHelper 'actionable-textarea', (options) ->
  Ember.assert('You can only pass attributes to the `actionable-textarea` helper, not arguments', arguments.length < 2)

  hash = options.hash
  types = options.hashTypes

  normalizeHash(hash, types)
  Ember.Handlebars.helpers.view.call(@, App.ActionableTextareaComponent, options)
