
events = {}

handler_on = (event, callback) =>
  events[event] ||= []
  events[event].push(callback)

handler_fire = (event, args...) ->
  if callbacks = events[event]
    for callback in callbacks
      try
        callback(args...)
      catch error
        console.log("Error in callback for '#{event}': '#{error}'")

module.exports = { on: handler_on, fire: handler_fire }
