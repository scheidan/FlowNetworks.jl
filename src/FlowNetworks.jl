## =======================================================
## Project: FlowNetworks
##
##  Andreas Scheidegger -- andreas.scheidegger@eawag.ch
## =======================================================


module FlowNetworks

using Graphs


export Location, FlowNetwork
export init_flow_net, add_segment!, is_flowconneted, dist
export flowpath, upstream_segments, upstream_ends, upstream_paths
export netspaceN, netspaceDist, plot



## ---------------------------------
## define types

type Source
    index::Int
    label::UTF8String

    depth::Int                          # number of segments to 'outflow'
    length2root::Float64                # distance from the 'outflow'
    x::Float64                          # geographical coordiantes
    y::Float64                          #       "           "
end

typealias Sink Source



immutable Location
    x::Float64                          # distance from sink (i.e. the *down*stream source)
    time::Float64
    segment::ExEdge                     # segment

    function Location(x, time, segment)
        segment.attributes["length"] < x ? error("x can't be larger than the segment length!") : nothing
        new(x, time, segment)
    end
end


## defines a Locating with labels from sink and source
function Location(x::Float64, time::Float64, sink_label::String, source_label::String, g)

    f(e) = (target(e).label == sink_label) & (source(e).label == source_label)
    segment = filter(f, edges(g))

    size(segment,1)>1 ? error("Labels are not unique!") : nothing
    size(segment,1)==0 ? error("No matching segment found!") : nothing

    Location(x, time, segment[1])
end

## defines a Locating with index of segment
function Location(x::Float64, time::Float64, segment_index::Int, g)

    segment = filter(e -> e.index == segment_index, edges(g))
    size(segment,1)==0 ? error("No matching segment found!") : nothing

    Location(x, time, segment[1])
end

## nicer Type names
typealias FlowNetwork AbstractGraph{Source, ExEdge{Source}}
typealias Segment ExEdge


## ---------------------------------
## functions to create a network

function init_flow_net(sink_lable, coor::Array{Float64})
    ## out flow
    sink = [Sink(1, sink_lable, 0, 0.0, coor[1], coor[2])]
    ## no segments
    segments = Segment{Source}[]
    G = graph(sink, segments)
end


## Attribute to the segments are added as tuples (String, Any)
function add_segment!(g::FlowNetwork, sink::Sink, label::String,
                      coor::Array{Float64}, attr...)

    ## compute length (assuming a straight line)
    length = sqrt((coor[1]-sink.x)^2 + (coor[2]-sink.y)^2)

    ## add new source
    index = num_vertices(g) + 1
    new_source = Source(index,
                        label,
                        sink.depth + 1,
                        sink.length2root + length,
                        coor[1],
                        coor[2])

    add_vertex!(g, new_source)

    ## add segments
    new_connetion = Segment(num_edges(g) + 1, new_source , sink)

    new_connetion.attributes["length"] = length
    ## add additional attributes
    for a in attr
        new_connetion.attributes[a[1]] = a[2]
    end

    add_edge!(g, new_connetion)

    println("added segement between:")
    println("source ($index, $label)")
    println("sink ($(sink.index), $(sink.label))")
end


function add_segment!(g::FlowNetwork, sink_label::String,  label::String, coor::Array{Float64}, attr...)
    sink = filter(x -> x.label == sink_label, vertices(g))
    size(sink,1)>1 ? error("Label '$sink_label' is not unique!") : nothing
    size(sink,1)==0 ? error("Label '$sink_label' is not defined!") : nothing
    add_segment!(g, sink[1], label, coor, attr...)
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
    return d
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

    return d
end



function flowpath(g::FlowNetwork, seg1::Segment, seg2::Segment)
    ## Returns an array of segments between 'seg1' and 'seg'2 that are *flow connected*.
    ## The higher segment is included, the lower *not*.
    ## If both locations are on the same segment, an empty array is returned.
    ## !!! If l1 and l2 are *not* flow connected, the result is not meaningful !!!

    flowp = Segment[]
    seg1 == seg2 && return(flowp)

    if source(seg1).depth < source(seg2).depth
        l = seg1; h = seg2
    else
        h = seg1; l = seg2
    end

    while source(h).depth > source(l).depth
        push!(flowp, h)

        h = collect(out_edges(target(h), g))[1]
    end
    return flowp
end


## Returns an array of segments between 'loc1' and 'loc2' that are *flow connected*.
## The segment of the higher location is included, the one of the lower *not*.
## If both locations are on the same segment, an empty array is returned.
## !!! If l1 and l2 are *not* flow connected, the result is not meaningful !!!
flowpath(g::FlowNetwork, l1::Location, l2::Location) = flowpath(g, l1.segment, l2.segment)


function upstream_segments(g::FlowNetwork, seg::Segment)
    ## Returns an array of all segments upstream of 'seg' including 'seg'.
    up_segments = Segment[seg]
    for s in in_edges(source(seg), g)
            append!(up_segments, upstream_segments(g, s))
    end
    up_segments
end


## Returns an array of all segments upstream of 'loc'.
upstream_segments(g::FlowNetwork, loc::Location) = upstream_segments(g, loc.segment)



function upstream_ends(g::FlowNetwork, seg::ExEdge)
    ## get all ends upstream of 'seg'
    sources = Source[]
    for s in in_edges(source(seg), g)
        so_s = source(s)
        if in_degree(so_s, g) != 0
            append!(sources, upstream_ends(g, s))
        else
            push!(sources, so_s)
        end
    end
    sources
end

upstream_ends(g::FlowNetwork, loc::Location) = upstream_ends(g, loc.segment)


function upstream_paths(g::FlowNetwork, seg::ExEdge)
    ## Returns an array of arrays of all flowpaths to the source of 'seg'
    paths = Vector{ExEdge}[]

    up_ends = upstream_ends(g, seg)
    for e in up_ends
        push!(paths, flowpath(g, seg, out_edges(e, g)[1]))
    end
    paths
end

## Returns an array of arrays of all flowpathes to the source of the segment of 'loc'
upstream_paths(g::FlowNetwork, loc::Location) = upstream_paths(g, loc.segment)



## ---------------------------------
## Misc

function netspaceN(g::FlowNetwork, n::Int, times::Array{Float64}=[0.0])
    ## create 'n' locations on every segement of 'g' at all point of 'times'
    edg = edges(g)

    locs = Location[]
    for e in edg
        l = e.attributes["length"]
        for x in linspace(l/(2*n), l-l/(2*n), n)
            for t in times
                push!(locs, Location(x, t, e))
            end
        end
    end
    locs
end


function netspaceDist(g::FlowNetwork, every::Real, times::Array{Float64}=[0.0])
    ## create a locations with a distance of 'every', at least one per segment
    ## at all point of 'times'
    edg = edges(g)

    locs = Location[]
    for e in edg
        l = e.attributes["length"]
        n = max(1, ifloor(l/every))
        for x in linspace(l/(2*n), l-l/(2*n), n)
            for t in times
                push!(locs, Location(x, t, e))
            end
        end
    end
    locs
end




## --- produces a *very simple* plot of the network
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
