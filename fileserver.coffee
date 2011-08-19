fs   = require 'fs'
mime = require 'mime'
url  = require 'url'

errors =
    403 : 'Forbidden'
    404 : 'File not found'
    405 : 'Method not allowed'
    500 : 'Internal server error'

exports.defaultConfig = () ->
    errorHandler : (req, res, code, err) ->
        console.log "#{req.url} #{err.message}" if err and err.message
        res.writeHead code
        res.end errors[code]
    base : '.'
    directoryListing : false
    headers :
        'Server' : 'fileserver.coffee'
        'Transfer-Encoding' : 'chunked'
    cache :
        enabled : true
        fileSizeLimit : 1024 * 32

cutTrailing = (str, chr) ->
    return str.substring 0, str.length-1 if str.charAt(str.length-1) is chr
    str

trueFn = () -> true
falseFn = () -> false

GET = 'GET'
HEAD = 'HEAD'

PATH_SEPARATOR = '/'

exports.getFileServer = (config) ->
    config.base = cutTrailing config.base, PATH_SEPARATOR
    if not config.cache.data
        config.cache.data = {}
    (req, res) ->
        return config.errorHandler req, res, 405 if req.method isnt GET and req.method isnt HEAD
        cacheHit = config.cache.data[req.url]
        if cacheHit
            return sendData req, res, null, cacheHit.buffer, cacheHit.headers, config
        resource = "#{config.base}/#{(url.parse req.url).pathname}"
        fs.stat resource, (err, stats) ->
            return config.errorHandler req, res, 404, err if err
            return sendFile req, res, resource, stats, config if stats.isFile()
            index = "#{cutTrailing resource,'/'}/index.htm"
            fs.stat index, (err, statsIdx) ->
                return listDirectory req, res, resource, stats, config if config.directoryListing and err
                return config.errorHandler req, res, 404, err if err
                return sendFile req, res, index, stats, config
            

cacheRequest = (req, resource, buffer, headers, config) ->
    config.cache.data[req.url] =
        resource : resource
        buffer : buffer
        headers : headers
    if resource
        fs.watchFile resource, (curr, prev) ->
            config.cache.data[req.url] = null
            fs.unwatchFile resource

mergeHeaders = (config, additional) ->
    result = {}
    result[key] = value for key,value of config
    result[key] = value for key,value of additional
    return result


sendData = (req, res, resource, buffer, headers, config, doCache) ->
    if req.headers['if-none-match'] is headers['ETag']
        res.writeHead 304, headers
        res.end null
    else
        res.writeHead 200, headers
        res.end buffer
    cacheRequest req, resource, buffer, headers, config if doCache and config.cache.enabled

listDirectory = (req, res, resource, stats, config) ->
    fs.readdir resource, (err, files) ->
        return config.errorHandler req, res, 500, err if err
        html = "<p>#{files.join "</p><p>"}</p>"
        headers = mergeHeaders config.headers,
            'Content-Type' : 'text/html'
            'Content-Length' : html.length
        sendData req, res, resource, html, headers, config if req.method is GET
        sendData req, res, resource, null, headers, config if req.method is HEAD

sendFile = (req, res, resource, stats, config) ->
   headers = mergeHeaders config.headers,
       'Content-Type' : mime.lookup resource
       'Content-Length' : stats.size
       'ETag' : "#{new Date(stats.mtime).getTime()}"
   if req.method is HEAD
        return sendData req, res, null, headers, config
    if req.method is GET
        fs.readFile resource, (err, data) ->
            return config.errorHandler req, res, 500, err if err
            sendData req, res, resource, data, headers, config, config.cache.enabled
            
