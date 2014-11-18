using FlowNetworks
using Base.Test

import Graphs

## --- create FlowNetwork

g = init_flow_net("Outflow")

add_segment!(g, Graphs.vertices(g)[1], "A",  200.0)
add_segment!(g, "A", "B", 50.0)
add_segment!(g, "A", "C", 20.0)
add_segment!(g, "C", "D", 2.0)
add_segment!(g, "C", "E", 5.0)

plot(g)

## --- define Locations

lo1 = Location(33.0, "Outflow", "A", g)
lo2 = Location(22.2, Graphs.edges(g)[2])
lo3a = Location(3.3, "A", "C", g)
lo3b = Location(3.3, 3, g)
lo4 = Location(9.9, "A", "C", g)

## illegal Locations
@test_throws ErrorException Location(3333.0, Graphs.edges(g)[1])
@test_throws ErrorException Location(-1.0, Graphs.edges(g)[1])
@test_throws ErrorException Location(3333.0, "Outflow", "A", g)
@test_throws ErrorException Location(-1.0, "Outflow", "A", g)


## --- compute distances

v = Graphs.vertices(g)

@test is_flowconneted(g, v[1], v[6]) == true
@test is_flowconneted(g, v[6], v[1]) == true
@test is_flowconneted(g, v[3], v[4]) == false
@test is_flowconneted(g, v[4], v[3]) == false

@test_approx_eq dist(g, lo1, lo1) 0.0
@test_approx_eq dist(g, lo1, lo2) 189.2
@test_approx_eq dist(g, lo1, lo3a) 170.3
@test_approx_eq dist(g, lo2, lo3a) 0.0
@test_approx_eq dist(g, lo3a, lo4) 6.6
@test_approx_eq dist(g, lo1, lo3a) dist(g, lo1, lo3b)
@test_approx_eq dist(g, lo1, lo2) dist(g, lo2, lo1)


## --- misc

@test length(netspaceN(g, 10)) == 50
@test length(netspaceDist(g, 10)) == 20 + 5 + 2 + 1 + 1
