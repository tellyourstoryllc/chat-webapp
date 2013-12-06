App.RoomsTableRowView = Ember.View.extend
  tagName: 'tr'
  classNameBindings: 'oddOrEven'

  room: Ember.computed.alias('content')

  oddOrEven: (->
    if @get('contentIndex') % 2 == 0
      'odd'
    else
      'even'
  ).property('contentIndex')
