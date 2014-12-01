using FlowNetworks
using Base.Test

import Graphs

## --- create FlowNetwork

g = init_flow_net("Outflow", [0.0, 0.0])

add_segment!(g, Graphs.vertices(g)[1], "A",  [200.0, 0.0], ("flow", 1.23))
add_segment!(g, "A", "B", [250, 0.0], ("flow", 0.23), ("speed", 300))
add_segment!(g, "A", "C", [220.0, 0.0])
add_segment!(g, "C", "D", [222.0, 0.0])
add_segment!(g, "C", "E", [225.0, 0,0])

plot(g)

## --- define Locations

lo1 = Location(33.0, 0.0, "Outflow", "A", g)
lo2 = Location(22.2, 0.0, Graphs.edges(g)[2])
lo3a = Location(3.3, 0.0, "A", "C", g)
lo3b = Location(3.3, 0.0, 3, g)
lo4 = Location(9.9,  0.0, "A", "C", g)
lo5 = Location(1.1,  0.0, "C", "E", g)

## illegal Locations
@test_throws ErrorException Location(3333.0, 0.0, Graphs.edges(g)[1])
@test_throws ErrorException Location(3333.0, 0.0, "Outflow", "A", g)


## --- compute distances

v = Graphs.vertices(g)

@test is_flowconneted(g, v[1], v[6]) == true
@test is_flowconneted(g, v[6], v[1]) == true
@test is_flowconneted(g, v[6], v[6]) == true
@test is_flowconneted(g, v[3], v[4]) == false
@test is_flowconneted(g, v[4], v[3]) == false

@test is_flowconneted(g, lo1, lo1) == true
@test is_flowconneted(g, lo1, lo2) == true
@test is_flowconneted(g, lo2, lo1) == true
@test is_flowconneted(g, lo2, lo3a) == false
@test is_flowconneted(g, lo3a, lo2) == false

@test_approx_eq dist(g, lo1, lo1) 0.0
@test_approx_eq dist(g, lo1, lo2) 189.2
@test_approx_eq dist(g, lo1, lo3a) 170.3
@test_approx_eq dist(g, lo2, lo3a) 0.0
@test_approx_eq dist(g, lo3a, lo4) 6.6
@test_approx_eq dist(g, lo1, lo3a) dist(g, lo1, lo3b)
@test_approx_eq dist(g, lo1, lo2) dist(g, lo2, lo1)


@test flowpath(g, lo1, lo5) == flowpath(g, lo5, lo1)
@test length(flowpath(g, lo1, lo5)) == 2
@test length(flowpath(g, lo3a, lo4)) == 0


## --- misc

@test length(netspaceN(g, 10)) == 50
@test length(netspaceDist(g, 10)) == 20 + 5 + 2 + 1 + 1

@test length(netspaceN(g, 10, [1.3, 3.4])) == 50*2
@test length(netspaceDist(g, 10, [1.3, 3.4])) == (20 + 5 + 2 + 1 + 1)*2
