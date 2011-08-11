fs   = require 'fs'
path = require 'path'
mime = require 'mime'

errors =
    403 : 'Forbidden'
    404 : 'File not found'
    405 : 'Method not allowed'
    500 : 'Internal server error'

exports.defaultConfig =
    () -> {
        errorHandler : (req, res, code, err) ->
            console.log "#{req.url} #{err.message}" if err and err.message
            res.writeHead code
            res.end errors[code]
        base : '.'
        directoryListing : false
        cache : {
            enabled : true
            fileSizeLimit : 4096
            timeLimit : 1000 * 60 * 5
            data : {}
        }
        headers :
            'Server' : 'fileserver.coffee'
    }

cutTrailing = (str, chr) ->
    return str.substring 0, str.length-1 if str.charAt(str.length-1) is chr
    str

trueFn = () ->
    true
falseFn = () ->
    false

exports.getFileServer = (config) ->
    config.base = cutTrailing config.base, '/'
    (req, res) ->
        config.errorHandler req, res, 405 if req.method isnt 'GET' and req.method isnt 'HEAD'
        resource = "#{config.base}/#{path.normalize req.url}"
        cacheData = cacheLookup req, config if config.cache.enabled
        if cacheData
            stats =
                mtime : cacheData.mtime
                size : cacheData.size
                isFile : trueFn
                isDirectory : falseFn
            return sendData req, res, stats, cacheData.data, config
        fs.stat resource, (err, stats) ->
            return config.errorHandler req, res, 404, err if err
            return sendFile req,res,resource,stats,config if stats.isFile()
            index = "#{cutTrailing resource, '/'}/index.htm"
            fs.stat index, (err, statsIdx) ->
                return listDirectory req, res, resource, stats, config if config.directoryListing and err
                return config.errorHandler req, res, 404, err if err
                return sendFile req, res, index, stats, config

cacheLookup = (req, config) ->
    data = config.cache.data[req.url]
    null if data and data.mtime + config.cache.timeLimit > new Date().getTime()
    data

cacheRequest = (req, stats, data, config) ->
    config.cache.data[req.url] = {
        data : data
        mtime : stats.mtime
        size : stats.size
    }

sendData = (req, res, stats, data, config, doCache) ->
    headers = {}
    headers[name] = config.headers[name] for name in config.headers
    headers['Last-Modified'] = new Date(stats.mtime).toUTCString()
    headers['Content-Length'] = stats.size if stats.isFile()
    headers['Content-Type'] = (mime.lookup req.url) if stats.isFile()
    headers['Content-Type'] = 'text/html' if stats.isDirectory() and data
    res.writeHead 200, headers
    res.end data if data
    res.end() if not data
    cacheRequest req, stats, data, config if config.cache.enabled and config.cache.fileSizeLimit > stats.size and doCache

sendFile = (req, res, resource, stats, config) ->
    return sendData req, res, stats, null, config if req.method is 'HEAD'
    fs.readFile resource, 'utf8', (err, data) ->
        return config.errorHandler req, res, 500, err if err
        sendData req, res, stats, data, config, true

listDirectory = (req, res, resource, stats, config) ->
    return sendData req,res,stats,null, config if req.method is 'HEAD'
    fs.readdir resource, (err, files) ->
        return config.errorHandler req, res, 500, err if err
        sendData req, res, stats, "<p>#{files.join "</p><p>"}</p>", config, false
