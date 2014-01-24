#= require record-array

# A set that also can be enumerated in order.  Specify sort order with
# `sortPropeties`, `sortAscending`, and `sortFunction`.  Enumerating
# `arrangedContent` will be in sorted order.
App.SortedSet = Ember.Object.extend Ember.MutableEnumerable,

  content: null

  _sortProperties: Ember.computed.alias('sortedContent.sortProperties')
  _sortAscending: Ember.computed.alias('sortedContent.sortAscending')
  _sortFunction: Ember.computed.alias('sortedContent.sortFunction')

  contains: Ember.computed.alias('content.contains')
  length: Ember.computed.alias('content.length')

  init: ->
    @_super(arguments...)
    @set('content', set = new Ember.Set())
    @set('contentArray', arr = set.toArray())
    @set('sortedContent', App.RecordArray.create(content: arr))
    # Copy to internal properties so the aliases aren't overwritten by user
    # values.
    for key in ['sortProperties', 'sortAscending', 'sortFunction']
      val = @get(key)
      @set("_#{key}", val) if val?

  arrangedContent: Ember.computed.alias('sortedContent')

  addObject: (obj) ->
    # Ember.Set doesn't support null or undefined.
    return obj if ! obj?

    set = @get('content')
    alreadyExists = set.contains(obj)
    if ! alreadyExists
      set.addObject(obj)
      @get('contentArray').addObject(obj)

    obj

  removeObject: (obj) ->
    # Ember.Set doesn't support null or undefined.
    return obj if ! obj?

    set = @get('content')
    alreadyExists = set.contains(obj)
    if alreadyExists
      set.removeObject(obj)
      @get('contentArray').removeObject(obj)

    obj
