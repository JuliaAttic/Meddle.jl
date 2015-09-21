"""
# Meddle
The middleware meddler.

This is documentation for Meddle.
"""
module Meddle

import HttpServer: Request,
                   Response,
                   Server,
                   run

export write!,
       resource,
       params,
       @middleware,
       FileServer,
       LogRequest,
       DefaultHandlers,
       handler,
       with,
       # from HttpServer
       Request,
       Response

MEDDLE_VERSION = 0.1

function app(middleware::Array{Function,1})
  reduce(|>, handler, middleware)
end

"""
`on` is just synatctic sugar
"""
on(port::Int) = port

"""
`serve` takes a port number and a **Handler** function
Fire up the server. Blocks and returns nothing.
"""
function serve(port::Int, handler::Function)
  run(Server(handler), port)
end


"""
`with` takes an array of **Middleware** and reduces them
all to a single handler function.

Usually this is passed to a `serve` function to start
the server.
"""
function with(stack::Array{Function,1})
  reduce(|>, (req, res) -> res , stack)
end

"""
When you just pass a function instead of an Array of Functions
"""
with(fn::Function) = fn(handler)

# Helper function for middleware
function write!(response::Response, msg::String)
  # Add msg to response data
  # These are converted to byte code
  response.data = vcat(response.data, msg.data)
end

# Handles an array of bytestring
function write!(response::Response, msg::Array{UInt8})
  response.data = vcat(response.data, msg)
end

# Handles String
write!(response::Response, msg::String) = write!(response, msg.data)

function resource(req::Request)
  return split(req.resource, "?")[1]
end

# Returns a dict of key => values
function params(req::Request)
  return split(req.resource, "?")[2]
end

# THIS IS THE DEFINITION OF A MIDDLEWARE
function middleware(fn::Function)
  function (req, res)
    # Do stuff here
    fn(req, res)
  end
end

"""
`@middleware(handler) -> middleware`

`@middleware` transforms a **Handler** function into a **Middleware** of the same name.

Use this macro to create **Middleware** out of a **Handler**.
The **Handler** returns a function that returns a **Middleware**.

This is the core macro and feature of Meddle. The `@middleware` macro avoids
some of the repetive code associate with writing closures for handlers and provides
the `next` keyword that references the next **Middleware** in the chain.

Here's a simplified version of the logging middleware.

    @middleware function LogRequests(req::Request, res::Response)
      println(req.resource)
      return next(req, res)
    end


Note that in Meddle, **Handler** and **Middleware** have exact defintions.
See the documentation for a proper explanation.
"""
macro middleware(handler::Expr)
  if handler.head == Symbol("=")  # Check that the operator is the assignment operator
    fnLabel = handler.args[1]  # The name of the function
  elseif handler.head == :function
    fnLabel = handler.args[1].args[1]
  else
    error("You must assign a name to your middleware!")
  end
  println(fnLabel) # the name of the function
  # Evaluates at global scope
  :(function $(esc(:($fnLabel)))(next::Function)
    $handler
  end)
end



"""
`handler` is a **Handler** that takes a `HttpServer.Request` and a
`HttpServer.Response` and returns a `HttpServer.Response`.

The `handler` function is the base function that kicks off the **Middleware**
chain. It's the first argument to a chain of **Middleware** and its the last
function that's called if a **Middleware** chain is not broken. At the moment,
it simply serves as a default although any function with the same
signature will do just as well.

Note that `HttpServer.Request/Response` is identical to `HttpCommon.Request/Response`
"""
function handler(req::Request, res::Response)
  res
end

###############################
##### Default Middleware #####
##############################
"""
`LogRequest` is a **Middleware** that logs incoming requests to the console.
"""
@middleware function LogRequest(req::Request, res::Response)
  println(string(req.method, " ", req.resource, " ", res.status))
  next(req, res)
end

"""
`DefaultHeaders` is a **Middleware** that writes the current Meddle version
to the Response header and continues to the next **Middleware**
"""
@middleware function DefaultHeaders(req::Request, res::Response)
    res.headers["Server"] = string(res.headers["Server"], " Meddle/$MEDDLE_VERSION")
    next(req, res)
end

"""
`UrlDecoder` is a **Middleware** that should just be a function
"""
@middleware function URLDecoder(req::Request, res::Response)
    rq_arr = split(req.http_req.resource, '?')
    req.state[:resource] = decodeURI(rq_arr[1])
    (length(rq_arr) > 1) && (req.state[:url_query] = rq_arr[2])
    if '=' in get(req.state, :url_query, "")
        req.state[:url_params] = parsequerystring(req.state[:url_query])
    end
    next(req, res)
end

"""
`FileServer` is a **Middleware** that serves files at the current working
directory.
"""
@middleware function FileServer(req::Request, res::Response)
  path_in_dir(p::String, d::String) = length(p) > length(d) && p[1:length(d)] == d
  m = match(r"^/+(.*)$", resource(req))
  if m != nothing
    # root = "/Users/ntdef/Desktop"
    root = pwd()
    path = normpath(root, m.captures[1])

    # protect against dir-escaping
    if !path_in_dir(path, root)
      return Response(400) # Bad Request
    end

    if isfile(path)
      data = readall(path)
      println(data)
      write!(res, data)
      return res
    else
      return Response(400)
    end
  end
end

end  # End module `Meddle`
