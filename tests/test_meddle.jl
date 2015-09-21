#!/usr/bin/local/julia
include("../src/Meddle.jl")

using FactCheck
using Meddle

facts("function `write`") do
  orig_str = "cool town"
  add_str = " drool town"

  context("It handles strings") do
    res = Response(orig_str)
    write!(res, add_str)

    @fact utf8(res.data) --> "cool town drool town"
  end

  context("It handles an array of UInt8") do
    o = orig_str
    a = add_str
    res = Response(o.data)
    write!(res, a.data)
    @fact utf8(res.data)--> string(o, a)
  end

end

facts("macro `middleware`") do
  @middleware function called_first(req, res)
    println("called first")
    next(req, res)
  end

  @middleware function called_last(req, res)
    println("called last")
    next(req, res)
  end

  context("it wraps functions") do

    @middleware function CoolHandler(req, res)
      return res
    end

    fn = CoolHandler((req, res) -> res)
    @fact isa(fn, Function) --> true
    @fact fn("req", "res") --> "res"
  end

  context("can be chained using `with`") do
    fn = with([called_last, called_first])
    @fact isa(fn, Function) --> true
  end
end

import HttpServer: Server
import Requests: get, text, statuscode

facts("Middleware can service requests") do
    context("using HTTP protocol on 127.0.0.1:8001") do
          @middleware function CoolBeans(req::Request, res::Response)
            if ismatch(r"^/hello/", req.resource)
              reply = string("Hello ", split(req.resource,'/')[3], "!")
            else
              reply = 404
            end
            return Response(reply)
          end

          # serve(on(host, 8001), with(CoolBeans))
          server = Server(with(CoolBeans))
          @async run(server, host=ip"127.0.0.1", port=8001)
          sleep(0.1)

          ret = Requests.get("http://127.0.0.1:8001/hello/travis")
          @fact text(ret) --> "Hello travis!"
          @fact statuscode(ret) --> 200
    end
end
