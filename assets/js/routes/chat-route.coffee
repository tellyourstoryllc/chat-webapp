#= require email-landing-route

App.ChatRoute = App.EmailLandingRoute.extend

  model: (params, transition) ->
    params.group_id
