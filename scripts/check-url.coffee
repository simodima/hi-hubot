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
#   hubot check-all - Check now all urls in list
#   hubot what are you checking - Show list of urls being checked
#   hubot empty url list
#
# Author:
#   toretto460

HTTP = require "http"
URL  = require "url"
REDIS = require "redis"
MD5 = require("blueimp-md5").md5
QUEUE = "check-url"

if process.env.REDISTOGO_URL?
  rtg = URL.parse(process.env.REDISTOGO_URL);
  publisher = REDIS.createClient(rtg.port, rtg.hostname);
  publisher.auth(rtg.auth.split(":")[1]);
else
  publisher = REDIS.createClient(6379, 'localhost').auth('');


# 2 minutes
frequency = 1000 * 60 * 2

check = (url, pub, msg) ->
  parsedUrl = URL.parse(url)
  options   =
    host: parsedUrl.host
    port: 80
    path: parsedUrl.path
    method: 'GET'

  req = HTTP.request options, (res) ->
    start_time = new Date().getTime()
    body = ""
    res.setEncoding("utf8")
    res.on "data", (chunk) ->
      body += chunk
    res.on "end", () ->
      end_time = new Date().getTime()
      response_time = end_time - start_time
      data =
        response:
          body: body
          status: res.statusCode
      if pub?
        message = JSON.stringify({'id': MD5(url), 'url' : url, 'code' : res.statusCode, "response_time" : response_time})
        pub.publish(QUEUE, message)
      if msg?
        msg.send url + "\t\t : " + res.statusCode

  req.on "error", (e) ->
    console.log(e)

  req.end()



module.exports = (robot) ->

  keepAlive = (msg) ->
    robot.brain.data.urls ?= []

    for url in robot.brain.data.urls
      try
        check(url, publisher, msg)
      catch e
        console.log("that probably isn't a url: " + url + " -- " + e)

    setTimeout (->
      keepAlive()
    ), frequency

  keepAlive(msg)


  robot.respond /check (.*)$/i, (msg) ->
    url = msg.match[1]
    robot.brain.data.urls ?= []

    if url in robot.brain.data.urls
      msg.send "I already am."
    else
      robot.brain.data.urls.push url
      msg.send "OK. I'll check that url every " + frequency/1000 + " seconds."
    keepAlive(msg)




  robot.respond /empty url list$/i, (msg) ->
    robot.brain.data.urls = []
    msg.send "Now url list is empty."




  robot.respond /check-all$/i, (msg) ->
    robot.brain.data.urls ?= []
    msg.send "Start checking"

    for url in robot.brain.data.urls
      check(url, publisher, msg)


   
    
  robot.respond /don'?t check (.*)$/i, (msg) ->
    url = msg.match[1]
    robot.brain.data.urls ?= []

    robot.brain.data.urls.splice(robot.brain.data.urls.indexOf(url), 1);
    msg.send "OK. I've removed that url from my list of urls to check."




  robot.respond /what are you checking/i, (msg) ->
    robot.brain.data.urls ?= []

    if robot.brain.data.urls.length > 0
      msg.send "These are the urls I'm checking\n\n" + robot.brain.data.urls.join('\n')
    else
      msg.send "i'm not currently checking any urls alive. Why don't you add one."