# Substitutes emoticons into user text.
Ember.Handlebars.registerBoundHelper 'evalMessageText', (text) ->
  escapedText = Ember.Handlebars.Utils.escapeExpression(text)

  escapedText.replace /\((\w+?)\)/g, (fullMatch, capture) ->
    emoticon = App.Emoticon.lookupByName(fullMatch)
    if emoticon?
      "<img src='#{emoticon.get('imageUrl')}'>"
    else
      fullMatch
  .htmlSafe()


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
