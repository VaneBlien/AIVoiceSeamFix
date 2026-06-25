# test_registry.jl
# 算法注册中心测试

using Test
using AIVoiceSeamFix.Types
using AIVoiceSeamFix.Params
using AIVoiceSeamFix.Interface
using AIVoiceSeamFix.Registry
using AIVoiceSeamFix.Errors

# ============================================================
# Mock 算法
# ============================================================

struct MockRepair <: AbstractRepairAlgorithm end
algorithm_id(::MockRepair) = "mock_repair"
algorithm_name(::MockRepair) = "Mock Repair"
algorithm_mode(::MockRepair) = "repair"

struct MockJoin <: AbstractJoinAlgorithm end
algorithm_id(::MockJoin) = "mock_join"
algorithm_name(::MockJoin) = "Mock Join"
algorithm_mode(::MockJoin) = "join"

# ============================================================
# AlgorithmRegistry
# ============================================================

@testset "AlgorithmRegistry" begin
    @testset "construction" begin
        reg = AlgorithmRegistry()
        @test reg isa AlgorithmRegistry
        @test isempty(list_algorithms(reg))
    end

    @testset "register_algorithm!" begin
        reg = AlgorithmRegistry()
        alg = MockRepair()

        result = register_algorithm!(reg, alg)
        @test result === reg  # 返回自身，方便链式调用
        @test length(list_algorithms(reg)) == 1
    end

    @testset "duplicate registration" begin
        reg = AlgorithmRegistry()
        register_algorithm!(reg, MockRepair())

        @test_throws ErrorException register_algorithm!(reg, MockRepair())
    end

    @testset "register multiple algorithms" begin
        reg = AlgorithmRegistry()
        register_algorithm!(reg, MockRepair())
        register_algorithm!(reg, MockJoin())

        algs = list_algorithms(reg)
        @test length(algs) == 2
    end
end

# ============================================================
# get_algorithm
# ============================================================

@testset "get_algorithm" begin
    reg = AlgorithmRegistry()
    register_algorithm!(reg, MockRepair())
    register_algorithm!(reg, MockJoin())

    @testset "existing algorithm" begin
        alg = get_algorithm(reg, "mock_repair")
        @test alg isa MockRepair
        @test algorithm_id(alg) == "mock_repair"
    end

    @testset "unknown algorithm" begin
        @test_throws UnknownAlgorithmError get_algorithm(reg, "nonexistent")
    end

    @testset "case sensitive" begin
        @test_throws UnknownAlgorithmError get_algorithm(reg, "MOCK_REPAIR")
    end
end

# ============================================================
# list_algorithms
# ============================================================

@testset "list_algorithms" begin
    reg = AlgorithmRegistry()
    @test isempty(list_algorithms(reg))

    register_algorithm!(reg, MockRepair())
    register_algorithm!(reg, MockJoin())

    algs = list_algorithms(reg)
    @test length(algs) == 2

    ids = sort([algorithm_id(a) for a in algs])
    @test ids == ["mock_join", "mock_repair"]
end

# ============================================================
# list_by_mode
# ============================================================

@testset "list_by_mode" begin
    reg = AlgorithmRegistry()
    register_algorithm!(reg, MockRepair())
    register_algorithm!(reg, MockJoin())

    @testset "repair mode" begin
        repair_algs = list_by_mode(reg, "repair")
        @test length(repair_algs) == 1
        @test algorithm_id(repair_algs[1]) == "mock_repair"
    end

    @testset "join mode" begin
        join_algs = list_by_mode(reg, "join")
        @test length(join_algs) == 1
        @test algorithm_id(join_algs[1]) == "mock_join"
    end

    @testset "unknown mode" begin
        unknown = list_by_mode(reg, "unknown")
        @test isempty(unknown)
    end
end

# ============================================================
# algorithm_info via registry
# ============================================================

@testset "algorithm_info via registry" begin
    reg = AlgorithmRegistry()
    register_algorithm!(reg, MockRepair())

    alg = get_algorithm(reg, "mock_repair")
    info = AIVoiceSeamFix.Interface.algorithm_info(alg)
    @test info["id"] == "mock_repair"
    @test info["mode"] == "repair"
end

println("✅ All registry tests passed!")