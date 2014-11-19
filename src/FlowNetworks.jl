## =======================================================
## Project: FlowNetworks
##
##  Andreas Scheidegger -- andreas.scheidegger@eawag.ch
## =======================================================


module FlowNetworks

using Graphs


export Location
export init_flow_net, add_segment!, is_flowconneted, dist, netspaceN, netspaceDist, plot



## ---------------------------------
## define types

type Source
    index::Int
    label::UTF8String

    depth::Int                          # number of segments to 'outflow'
    length2root::Float64                # distance from the 'outflow'
end

typealias Sink Source



type Location
    x::Float64                          # distance from *down*stream source
    segment::ExEdge                     # segment

    function Location(x, segment)
        segment.attributes["length"] < x ? error("x can't be larger than the segment length") : nothing
        x < 0 ? error("x can't be negative") : nothing
        new(x, segment)
    end
end

## defines a Locating with labels from sink and source
function Location(x::Float64, sink_label::String, source_label::String, g)

    f(e) = (target(e).label == sink_label) & (source(e).label == source_label)
    segment = filter(f, edges(g))

    size(segment,1)>1 ? error("Labels are not unique!") : nothing
    size(segment,1)==0 ? error("No matching segment found!") : nothing

    Location(x, segment[1])
end

## defines a Locating with index of segment
function Location(x::Float64, segment_index::Int, g)

    segment = filter(e -> e.index == segment_index, edges(g))
    size(segment,1)==0 ? error("No matching segment found!") : nothing

    Location(x, segment[1])
end

## nicer Type name
typealias FlowNetwork AbstractGraph{Source, ExEdge{Source}}


## ---------------------------------
## functions to create a network

function init_flow_net(sink_lable = "outflow")
    ## out flow
    sink = [Sink(1, sink_lable, 0, 0.0)]
    ## no segments
    segments = ExEdge{Source}[]
    G = graph(sink, segments)
end


function add_segment!(g::FlowNetwork, sink::Sink, label::String, length::Float64)

    ## add new source
    index = num_vertices(g) + 1
    new_source = Source(index,
                        label,
                        sink.depth + 1,
                        sink.length2root + length)

    add_vertex!(g, new_source )

    ## add segments
    new_connetion = ExEdge(num_edges(g) + 1, new_source , sink)
    new_connetion.attributes["length"] = length
    add_edge!(g, new_connetion)

    println("added segement between:")
    println("source ($index, $label)")
    println("sink ($(sink.index), $(sink.label))")
end


function add_segment!(g::FlowNetwork, sink_label::String,  label::String, length::Float64,)
    sink = filter(x -> x.label == sink_label, vertices(g))
    size(sink,1)>1 ? error("Label '$sink_label' is not unique!") : nothing
    size(sink,1)==0 ? error("Label '$sink_label' is not defined!") : nothing
    add_segment!(g, sink[1], label, length)
end




## ---------------------------------
## compute distances

function is_flowconneted(g::FlowNetwork, v1::Source, v2::Source)
    if v1.depth < v2.depth
        l = v1; h = v2
    else
        h = v1; l = v2
    end
    ## travel down until the same depth is reached
    while(h.depth > l.depth)
        h = collect(out_neighbors(h, g))[1]
    end
    h == l
end

function is_flowconneted(g::FlowNetwork, l1::Location, l2::Location)
    is_flowconneted(g, source(l1.segment), source(l2.segment))
end



function dist(g::FlowNetwork, v1::Source, v2::Source)
    ## compute distance if v1, and v2 are flow connetced, else return 0.0
    d = 0.0
    if is_flowconneted(g, v1::Source, v2::Source)
       d += abs(v1.length2root - v2.length2root)
    end
    return(d)
end


function dist(g::FlowNetwork, l1::Location, l2::Location)
    ## compute distance if v1, and v2 are flow connetced, else return 0.0
    s1 = source(l1.segment)
    s2 = source(l2.segment)
    length1 = l1.segment.attributes["length"]
    length2 = l2.segment.attributes["length"]

    d = 0.0
    if is_flowconneted(g, s1, s2)
        d += abs( (s1.length2root - length1 + l1.x) - (s2.length2root - length2 + l2.x) )
    end

    return(d)
end


## ---------------------------------
## Misc

function netspaceN(g::FlowNetwork, n::Int)
    ## create 'n' locations on  every segement of 'g'
    edg = edges(g)

    locs = Location[]
    for e in edg
        l = e.attributes["length"]
        for x in linspace(l/(2*n), l-l/(2*n), n)
            push!(locs, Location(x, e))
        end
    end
    locs
end

function netspaceDist(g::FlowNetwork, every::Real)
    ## create a locations with a distance of 'every', at least one per segment
    edg = edges(g)

    locs = Location[]
    for e in edg
        l = e.attributes["length"]
        n = max(1, ifloor(l/every))
        for x in linspace(l/(2*n), l-l/(2*n), n)
            push!(locs, Location(x, e))
        end
    end
    locs
end




## --- produces a *very simple* plot network
function plot(v::Source, g::FlowNetwork, pre::String)

    ## construct string to print
    str_mid = "\u251C\u2500"
    str = string(pre, str_mid, " ", v.label)
    l_label = length(v.label)

    vn = in_neighbors(v, g)
    length(vn) > 0 ? println(str, " <\u2510") : println(str)

    if length(vn) > 0
        for vni in vn
            plot(vni, g, string(pre, "\u2502    ", " "^l_label))
        end
    end

end

function plot(g::FlowNetwork)
    println("")
    plot(vertices(g)[1], g, "  ")
    println("")
end

## -----------


end # module
