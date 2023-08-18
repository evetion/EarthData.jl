using EarthData
using Test

@testset "EarthData.jl" begin
    gg = granules(short_name="GEDI02_A")
    @test length(gg) == 10

    g = gg[1]
    @test g isa EarthData.Granule

    @test_throws "Something went wrong: The CMR does not allow quer" granules()
end

@testset "AWS" begin
    # Test package extension
end
