# Description:
#   Check sites status with http request, i will test your sites every 2 minutes
#   and send response info to redis 'check-url' queue
#
# Dependencies:
#   redis
#
# Configuration:
#   None
#
# Commands:
#   hubot check `http://www.google.com` - Add single url into check-list and will check every 2 minutes
#   hubot check all - Check now all urls in list
#   hubot what are you checking - Show list of urls being checked
#   hubot empty url list
#
# Author:
#   toretto460

HTTP = require "http"
URL  = require "url"
REDIS = require "redis"
QUEUE = "check-url"

frequency = 10000

publisher = REDIS.createClient(6379, 'localhost');
publisher.auth('');

check = (url, pub, msg) ->
  parsedUrl = URL.parse(url)
  options   =
    host: parsedUrl.host
    port: 80
    path: parsedUrl.path
    method: 'GET'

  req = HTTP.request options, (res) ->

    body = ""
    res.setEncoding("utf8")
    res.on "data", (chunk) ->
      body += chunk
    res.on "end", () ->
      data =
        response:
          body: body
          status: res.statusCode
      if pub?
        pub.publish(QUEUE, url + "**" + res.statusCode)
      if msg?
        msg.send url + "\t\t : " + res.statusCode

  req.on "error", (e) ->
    console.log(e)

  req.end()



module.exports = (robot) ->

  keepAlive = () ->
    robot.brain.data.keepalives ?= []

    for url in robot.brain.data.keepalives
      try
        check(url, publisher)
      catch e
        console.log("that probably isn't a url: " + url + " -- " + e)

    setTimeout (->
      keepAlive()
    ), frequency

  keepAlive()


  report = () ->
    db = REDIS.createClient(6379,'localhost')
    db.auth('')
    db.subscribe(QUEUE)
    
    db.on 'message', (channel, message) ->
      #robot.logger.info(message)
  
  report()

  robot.respond /check (.*)$/i, (msg) ->
    url = msg.match[1]

    robot.brain.data.keepalives ?= []

    if url in robot.brain.data.keepalives
      msg.send "I already am."
    else
      robot.brain.data.keepalives.push url
      msg.send "OK. I'll check that url every " + frequency/1000 + " seconds."

  robot.respond /empty url list$/i, (msg) ->
    
    robot.brain.data.keepalives = []

    msg.send "Now url list is empty."

  robot.respond /check-all$/i, (msg) ->
    
    robot.brain.data.keepalives ?= []

    for url in robot.brain.data.keepalives
      console.log(url)
      check(url, null, msg)
   
    msg.send "Done."

  robot.respond /don'?t check (.*)$/i, (msg) ->
    url = msg.match[1]

    robot.brain.data.keepalives ?= []

    robot.brain.data.keepalives.splice(robot.brain.data.keepalives.indexOf(url), 1);
    msg.send "OK. I've removed that url from my list of urls to keep alive."

  robot.respond /what are you checking/i, (msg) ->
    robot.brain.data.keepalives ?= []

    if robot.brain.data.keepalives.length > 0
      msg.send "These are the urls I'm keeping alive\n\n" + robot.brain.data.keepalives.join('\n')
    else
      msg.send "i'm not currently keeping any urls alive. Why don't you add one."
