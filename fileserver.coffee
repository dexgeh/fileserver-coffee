fs = require 'fs'
path = require 'path'
mime = require 'mime'

exports.serverHeader = path.basename(__filename)

errors =
    403 : 'Forbidden'
    404 : 'File not found'
    405 : 'Method not allowed'
    500 : 'Internal server error'

handleError = (req, res, code, err, errorHandler) ->
    return errorHandler req, res, code, err if errorHandler
    console.log "#{req.url} #{err.message}" if err
    res.writeHead(code)
    res.end errors[code]

exports.getFileServer = (base, directoryListing, errorHandler) ->
    (req, res) ->
        return handleError req,res,405,null,errorHandler if req.method isnt 'GET' and req.method isnt 'HEAD'
        resource = base + path.normalize(req.url)
        resource = resource.substring(0, resource.length-1) if resource.charAt(resource.length-1) is "/"
        fs.stat resource, (err, dstats) ->
            return handleError req,res,404,err,errorHandler if err
            if dstats.isDirectory()
                fs.stat "#{resource}/index.htm", (err, stats) ->
                    return listDirectory req, res, resource, dstats, errorHandler if err and directoryListing
                    return handleError req,res,404,err,errorHandler if err
                    return serveResource req, res, "#{resource}/index.htm", stats, errorHandler if stats.isFile()
                    handleError req,res,403, null,errorHandler
            else
                return serveResource req, res, resource, dstats, errorHandler

sendData = (req, res, mtime, size, contentType, data) ->
    headers =
        'Server' : exports.serverHeader
        'Last-Modified' : new Date(mtime).toUTCString()
    headers['Content-Length'] = size if size
    headers['Content-Type'] = contentType if contentType
    res.writeHead 200, headers
    res.end data if data
    res.end() if not data

listDirectory = (req, res, resource, stats, errorHandler) ->
    if req.method is 'HEAD'
        sendData req, res, stats.mtime, null, null, null
    if req.method is 'GET'
        fs.readdir resource, (err, files) ->
            return handleError req,res,500,err,errorHandler if err
            data = "<p>#{files.join("</p><p>")}</p>"
            sendData req, res, stats.mtime, data.length, 'text/html', data

serveResource = (req, res, resource, stats, errorHandler) ->
    if req.method is 'HEAD'
        sendData req, res, stats.mtime, stats.size, (mime.lookup resource), null
    if req.method is 'GET'
        fs.readFile resource, 'utf8', (err, data) ->
            return handleError req,res,500,err,errorHandler if err
            sendData req, res, stats.mtime, stats.size, (mime.lookup resource), data

