using Impute
using Test
using DataFrames
using RDatasets
using Statistics

@testset "Impute" begin
    a = Vector{Union{Float64, Missing}}(1.0:1.0:20.0)
    a[[2, 3, 7]] .= missing
    mask = map(!ismissing, a)

    @testset "Drop" begin
        result = impute(a, :drop; limit=0.2)
        expected = copy(a)
        deleteat!(expected, [2, 3, 7])

        @test result == expected
    end

    @testset "Interpolate" begin
        result = impute(a, :interp; limit=0.2)
        @test result == collect(1.0:1.0:20)
        @test result == interp(a)
    end

    @testset "Fill" begin
        @testset "Value" begin
            fill_val = -1.0
            result = impute(a, :fill, fill_val; limit=0.2)
            expected = copy(a)
            expected[[2, 3, 7]] .= fill_val

            @test result == expected
        end

        @testset "Mean" begin
            result = impute(a, :fill; limit=0.2)
            expected = copy(a)
            expected[[2, 3, 7]] .= mean(a[mask])

            @test result == expected
        end
    end

    @testset "LOCF" begin
        result = impute(a, :locf; limit=0.2)
        expected = copy(a)
        expected[2] = 1.0
        expected[3] = 1.0
        expected[7] = 6.0

        @test result == expected
    end

    @testset "NOCB" begin
        result = impute(a, :nocb; limit=0.2)
        expected = copy(a)
        expected[2] = 4.0
        expected[3] = 4.0
        expected[7] = 8.0

        @test result == expected
    end

    @testset "DataFrame" begin
        data = dataset("boot", "neuro")
        df = impute(data, :interp; limit=1.0)
    end

    @testset "Matrix" begin
        data = Matrix(dataset("boot", "neuro"))

        @testset "Drop" begin
            result = Iterators.drop(data)
            @test size(result, 1) == 4
        end

        @testset "Fill" begin
            result = impute(data, :fill, 0.0; limit=1.0)
            @test size(result) == size(data)
        end
    end

    @testset "Not enough data" begin
        @test_throws ImputeError impute(a, :drop)
    end

    @testset "Chain" begin
        data = Matrix(dataset("boot", "neuro"))
        result = chain(
            data,
            Impute.Interpolate(),
            Impute.LOCF(),
            Impute.NOCB();
            limit=1.0
        )

        @test size(result) == size(data)
        # Confirm that we don't have any more missing values
        @test !any(ismissing, result)
    end

    @testset "Alternate missing functions" begin
        data1 = dataset("boot", "neuro")                # Missing values with `missing`
        data2 = impute(data1, :fill, NaN; limit=1.0)     # Missing values with `NaN`

        @test impute(data1, :drop; limit=1.0) == dropmissing(data1)

        result1 = chain(data1, Impute.Interpolate(), Impute.Drop(); limit=1.0)
        result2 = chain(data2, isnan, Impute.Interpolate(), Impute.Drop(); limit=1.0)
        @test result1 == result2
    end

    @testset "SVD" begin
        data = Matrix(dataset("Ecdat", "Electricity"))
        for i in 1:50
            idx = rand(1:length(data))
            data[idx] = missing
        end

        result = Impute.svd(data)
    end
end
