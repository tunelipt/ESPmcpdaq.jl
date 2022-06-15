module ESPmcpdaq

using PyCall
using AbstractDAQs
import Dates: DateTime, now
import DataStructures: OrderedDict
export DAQespmcp, daqconfigdev, daqstop, daqacquire
export daqstart, daqread, samplesread, isreading



mutable struct DAQespmcp <: AbstractDAQ
    devname::String
    Eref::Float64
    ip::String
    port::Int32
    server::PyObject
    conf::DAQConfig
    chans::Vector{Int}
    channames::Vector{String}
    chanidx::OrderedDict{String,Int}
    time::DateTime
end

function DAQespmcp(devname, ip, port=9541, Eref=2.5)
    xmlrpc = pyimport("xmlrpc.client")
    server = xmlrpc.ServerProxy("http://$ip:$port")
    conf = DAQConfig(devname=devname, ip=ip, model="ESPMCPdaq")
    chans = collect(1:32)
    channames = string.('E', numstring.(chans, 2))
    chanidx = OrderedDict{String,Int}()
    for (i,ch) in enumerate(channames)
        chanidx[ch] = i
    end

    DAQespmcp(devname, Eref, ip, port, server, conf,
              chans, channames, chanidx,
              now())

    
end

AbstractDAQs.devtype(dev::DAQespmcp) = "DAQespmcp"

function AbstractDAQs.daqconfigdev(dev::DAQespmcp; kw...)

    if haskey(kw, :avg)
        avg = round(Int, kw[:avg])
        dev.server["avg"](avg)
        dev.conf.ipars["avg"] = avg
    end

    if haskey(kw, :fps)
        fps = round(Int, kw[:fps])
        dev.server["fps"](fps)
        dev.conf.ipars["fps"] = fps
    end

    if haskey(kw, :period)
        fps = round(Int, kw[:period])
        dev.server["period"](period)
        dev.conf.ipars["period"] = period
    end
    
end

function AbstractDAQs.daqstop(dev::DAQespmcp)
    dev.server["stop"]()
end

function parse_xmlrpc_response(x, Eref)
    nsamples = x[2]
    nchans = x[3]
    freq = x[4]
    E = reshape(reinterpret(UInt16, read(IOBuffer(x[1].data),
                                         2*nsamples*nchans)) .* Eref/4095,
                (nchans, nsamples))
    return E, freq
end


    

function AbstractDAQs.daqacquire(dev::DAQespmcp)
    dev.time = now()
    E,f =   parse_xmlrpc_response(dev.server["scanbin"](), dev.Eref)
    return MeasData{Matrix{Float64}}(devname(dev), devtype(dev),
                                     dev.time, f, E, dev.chanidx)
end

function AbstractDAQs.daqstart(dev::DAQespmcp)
    dev.time = now()
    dev.server["start"]()
    
end

function AbstractDAQs.daqread(dev::DAQespmcp)
    E,f =   parse_xmlrpc_response(dev.server["readbin"](), dev.Eref)
    return MeasData{Matrix{Float64}}(devname(dev), devtype(dev),
                                     dev.time, f, E, dev.chanidx)
end

function AbstractDAQs.isreading(dev::DAQespmcp)
    return dev.server["isacquiring"]()
end

function AbstractDAQs.samplesread(dev::DAQespmcp)
    return dev.server["samplesread"]()
end


end
