using Test: @test, @testset, @test_throws
using Logging: Logging, with_logger
using LoggingExtras: FormatLogger
using LoggingFormats: LoggingFormats, Truncated, JSON, LogFmt
import JSON3

@testset "Truncating" begin
    @test LoggingFormats.shorten_str("αβγαβγ", 3) == "αβ…"
    @test LoggingFormats.shorten_str("αβγαβγ", 4) == "αβγ…"
    @test LoggingFormats.shorten_str("julia", 3) == "ju…"
    @test LoggingFormats.shorten_str("julia", 4) == "jul…"
    @test LoggingFormats.shorten_str("julia", 5) == "julia"

    @test_throws ErrorException Truncated(0)
    @test_throws ErrorException Truncated(-5)

    trunc_fun = Truncated(30)
    io = IOBuffer()
    truncating_logger = FormatLogger(trunc_fun, io)
    with_logger(truncating_logger) do
        @info "a"^50
    end
    str = String(take!(io))

    @test occursin("Info: aaaaaaaaaaaaaaaaaaaaaaaaaaaaa…", str)

    io = IOBuffer()
    truncating_logger = FormatLogger(trunc_fun, io)
    with_logger(truncating_logger) do
        long_var = "a"^50
        @info "a_message" long_var
    end
    str = String(take!(io))

    @test occursin("│   long_var = aaaaaaaaaaaaaa…", str)

    io = IOBuffer()
    truncating_logger = FormatLogger(trunc_fun, io)
    with_logger(truncating_logger) do
        long_var = "a"^50
        short_var = "a"
        @info "a_message" long_var short_var
    end
    str = String(take!(io))
    @test occursin("│   long_var = aaaaaaaaaaaaaa…", str)
    @test occursin("│   short_var = a", str)
end

@testset "JSON" begin
    @test LoggingFormats.lvlstr(Logging.Error + 1) == "error"
    @test LoggingFormats.lvlstr(Logging.Error) == "error"
    @test LoggingFormats.lvlstr(Logging.Error - 1) == "warn"
    @test LoggingFormats.lvlstr(Logging.Warn + 1) == "warn"
    @test LoggingFormats.lvlstr(Logging.Warn) == "warn"
    @test LoggingFormats.lvlstr(Logging.Warn - 1) == "info"
    @test LoggingFormats.lvlstr(Logging.Info + 1) == "info"
    @test LoggingFormats.lvlstr(Logging.Info) == "info"
    @test LoggingFormats.lvlstr(Logging.Info - 1) == "debug"
    @test LoggingFormats.lvlstr(Logging.Debug + 1) == "debug"
    @test LoggingFormats.lvlstr(Logging.Debug) == "debug"

    io = IOBuffer()
    with_logger(FormatLogger(JSON(), io)) do
        @debug "debug msg"
        @info "info msg"
        @warn "warn msg"
        @error "error msg"
    end
    json = [JSON3.read(x) for x in eachline(seekstart(io))]
    @test json[1].level == "debug"
    @test json[1].msg == "debug msg"
    @test json[2].level == "info"
    @test json[2].msg == "info msg"
    @test json[3].level == "warn"
    @test json[3].msg == "warn msg"
    @test json[4].level == "error"
    @test json[4].msg == "error msg"
    for i in 1:4
        @test json[i].line isa Int
        @test json[i].module == "Main"
        @test isempty(json[i].kwargs)
    end

    io = IOBuffer()
    with_logger(FormatLogger(JSON(), io)) do
        y = (1, 2)
        @info "info msg" x = [1, 2, 3] y
    end
    json = JSON3.read(seekstart(io))
    @test json.level == "info"
    @test json.msg == "info msg"
    @test json.module == "Main"
    @test json.line isa Int
    @test json.kwargs.x == "[1, 2, 3]"
    @test json.kwargs.y == "(1, 2)"
end

@testset "logfmt" begin
    io = IOBuffer()
    with_logger(FormatLogger(LogFmt(), io)) do
        @debug "debug msg"
        @info "info msg" _file="file with space.jl"
        @warn "msg with \"quotes\""
        @error "error msg with nothings" _module=nothing _file=nothing __line=nothing
        @error :notstring x = [1, 2, 3] y = "hello\" \"world"
    end
    strs = collect(eachline(seekstart(io)))
    @test occursin("level=debug msg=\"debug msg\" module=Main", strs[1])
    @test occursin("file=\"", strs[1])
    @test occursin("group=\"", strs[1])
    @test occursin("level=info msg=\"info msg\" module=Main", strs[2])
    @test occursin("file=\"file with space.jl\"", strs[2])
    @test occursin("group=\"file with space\"", strs[2])
    @test occursin("level=warn msg=\"msg with \\\"quotes\\\"\" module=Main", strs[3])
    @test occursin("file=\"", strs[3])
    @test occursin("group=\"", strs[3])
    @test occursin("level=error msg=\"error msg with nothings\" module=nothing", strs[4])
    @test occursin("file=\"nothing\"", strs[4])
    @test occursin("line=\"nothing\"", strs[4])
    @test occursin("level=error msg=\"notstring\" module=Main", strs[5])
    @test occursin("x=\"[1, 2, 3]\" y=\"hello\\\" \\\"world\"", strs[5])
end
