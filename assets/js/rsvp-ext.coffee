# Deprecated: Use `RSVP.finally()` instead.
#
# Add `always` to Ember.RSVP.Promise that always runs and doesn't transform the
# result, similar to jQuery.Deferred's always.  This allows you to write an
# asynchronous version of a finally block.
#
# See https://github.com/tildeio/rsvp.js/issues/21
Ember.RSVP.Promise.prototype.always = (alwaysFn) ->
  # Do the same thing for either success or failure, without changing semantics.
  return @then (result) ->
    alwaysFn.call(@, result)
    return result
  , (error) ->
    alwaysFn.call(@, error)
    throw error
