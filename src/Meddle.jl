# Meddle is a Rack/Connect style middleware module
#
# Use the `middleware` function to build a `MidwareStack` of `Midware`.
# Pass the `MidwareStack`, plus `req::MeddleRequest, res::Response` to `handle` to
# run process the `req` through your `MidwareStack`.
#
# Build `Midware` with functions that accept `req::MeddleRequest, res::Response`.
# `Midware` should put any data it wants to pass in the `req.state` Dict.
#
# - Return `req, res` from your `Midware` to pass control to the next piece of
#   `Midware` in the stack.
# - Use `respond(req, res)` to short-circut the stack and return to the client.
#
# Usage:
#
#     using Http
#     using Meddle
#
#     stack = middleware(DefaultHeaders,
#                        CookieDecoder,
#                        FileServer(pwd()),
#                        NotFound)
#
#     http = HttpHandler((req, res) -> Meddle.handle(stack, req, res))
#
#     server = Server(http)
#     run(server, 8000)
#
module Meddle

# Version const, used in `Server` header.
MEDDLE_VERSION = "0.0"

using HttpServer
export Midware,
       MeddleRequest,
       DefaultHeaders,
       URLDecoder,
       CookieDecoder,
       BodyDecoder,
       FileServer,
       NotFound,
       MidwareStack,
       handle,
       middleware,
       respond

immutable MeddleRequest
    http_req::Request
    state::Dict
    params::Dict
end

# `Midware` only uses the `handler` right now.
# Expects & Provides may be leveraged soon to do dependency resolution
# like `expects = ["cookies"]`, `provides = ["sessions"]`.
#
immutable Midware
    handler::Function
    expects::Array
    provides::Array
end
Midware(handler::Function) = Midware(handler,[],[])

# `MidwareStack` is just an `Array` of `Midware`
typealias MidwareStack Array{Midware,1}

# `DefaultHeaders` writes the `Server` header on the `Response`
#
# This would be good as one of the first items in your stack
# because it does not depend on any other midware, and ensures
# that any `Response` sent will include the defaults.
#
DefaultHeaders = Midware() do req::MeddleRequest, res::Response
    res.headers["Server"] = string(res.headers["Server"], " Meddle/$MEDDLE_VERSION")
    req, res
end

# URLDecoder
#
# Decodes the URI encoding of req.resource.
# Turns the req.state[:url_query] "foo=hello%20world&bar=fun"
# into req.state[:url_params] # => ["foo" => "hello world", "bar" => "fun"]
#
# Should be pretty far forward in the stack, makes URLs and URL strings usable.
#
URLDecoder = Midware() do req::MeddleRequest, res::Response
    rq_arr = split(req.http_req.resource, '?')
    req.state[:resource] = decodeURI(rq_arr[1])
    (length(rq_arr) > 1) && (req.state[:url_query] = rq_arr[2])
    if '=' in get(req.state, :url_query, "")
        req.state[:url_params] = parsequerystring(req.state[:url_query])
    end
    req, res
end

# `CookieDecoder` builds `req.state[:cookies]` from `req.headers`.
#
# `req.state[:cookies]` will be a dictionary of Symbols to AbstractStrings.
# This should come fairly early in your stack,
# before anything that needs to use cookies.
#
CookieDecoder = Midware() do req::MeddleRequest, res::Response
    cookies = Dict()
    if haskey(req.http_req.headers, "Cookie")
        for pair in split(req.http_req.headers["Cookie"],"; ")
            kv = split(pair,"=")
            cookies[symbol(kv[1])] = kv[2]
        end
    end
    req.state[:cookies] = cookies
    req, res
end

# `BodyDecoder` builds `req.state[:data]` from `req.data`.
#
# `req.state[:data]` will be a dictionary of Symbols to AbstractStrings.
# This should come fairly early in your stack,
# before anything that needs to use POST data.
#
BodyDecoder = Midware() do req::MeddleRequest, res::Response
    if '=' in req.http_req.data
        req.state[:data] = parsequerystring(req.http_req.data)
    end
    req, res
end

# `FileServer` returns a `Midware` to serve files in `root`
#
# Checks for files that match `req.resource` relative to `root` directory.
# If no such file exists, then it passes to the next in the stack.
# If a file is found, it short-circuts and responds.
#

path_in_dir(p::AbstractString, d::AbstractString) = length(p) > length(d) && p[1:length(d)] == d

function FileServer(root::AbstractString)
    Midware() do req::MeddleRequest, res::Response
        m = match(r"^/+(.*)$", req.state[:resource])
        if m != nothing
            path = normpath(root, m.captures[1])
            # protect against dir-escaping
            if !path_in_dir(path, root)
                return respond(req, Response(400)) # Bad Request
            end
            if isfile(path)
                res.data = readall(path)
                return respond(req, res)
            end
        end
        req, res
    end
end

# `NotFound` always responds with a `404` error.
#
# This is useful as the last thing in your stack
# to handle all the "no idea what to do" requests.
#
NotFound = Midware() do req::MeddleRequest, res::Response
    respond(req, Response(404))
end

function middleware(midware...)
    Midware[typeof(m) == Function ? m() : m::Midware for m in midware]
end

# `handle` method runs the `req, res` through each `Midware` in `stack`.
#
# Stops and returns the response when complete ( `res.finished == true` ).
# Usually called in `HttpHandler.handle`
#
function handle(stack::MidwareStack, req::MeddleRequest, res::Response)
    for mid in stack
        # TODO: check these and throw useful error for bad returns
        req, res = mid.handler(req, res)
        if res.finished
            return res
        end
    end
    res
end

# `respond` is syntactic sugar for setting `res.finished` to true.
function respond(req::MeddleRequest, res::Response)
    res.finished = true
    req, res
end

end # module Meddle
