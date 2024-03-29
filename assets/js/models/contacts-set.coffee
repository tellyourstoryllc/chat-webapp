#= require sorted-set

# A sorted set that is only of user contacts.  Tracks on the user when it
# becomes a contact or not.
App.ContactsSet = App.SortedSet.extend

  updateUsers: true

  sortProperties: ['name']

  addObject: (obj) ->
    # Ember.Set doesn't support null or undefined.
    return obj if ! obj?

    set = @get('content')
    alreadyExists = set.contains(obj)
    if ! alreadyExists
      obj.set('isContact', true) if @get('updateUsers')
      set.addObject(obj)
      @get('contentArray').addObject(obj)

    obj

  removeObject: (obj) ->
    # Ember.Set doesn't support null or undefined.
    return obj if ! obj?

    set = @get('content')
    alreadyExists = set.contains(obj)
    if alreadyExists
      obj.set('isContact', false) if @get('updateUsers')
      set.removeObject(obj)
      @get('contentArray').removeObject(obj)

    obj
