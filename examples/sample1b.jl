using MetalCore

@show devices()
dev = MtlDevice(1)


#lib = MetalCore.LibraryWithFile(d, "default.metallib")
src = read(dirname(pathof(MetalCore))*"/Metal/kernels/add.metal", String)

bufferSize = 128
bufferA = MtlArray{Float32,1}(undef, tuple(bufferSize), storage=Shared)
bufferB = MtlArray{Float32,1}(undef, tuple(bufferSize), storage=Shared)
bufferC = MtlArray{Float32,1}(undef, tuple(bufferSize), storage=Shared)

vecA = unsafe_wrap(Vector{Float32}, bufferA.buffer, tuple(bufferSize))
vecB = unsafe_wrap(Vector{Float32}, bufferB.buffer, tuple(bufferSize))
vecC = unsafe_wrap(Vector{Float32}, bufferC.buffer, tuple(bufferSize))

using Random
rand!.([vecA, vecB])

## Setup
opts = MtlCompileOptions()
lib = MtlLibrary(dev, src, opts)

fun = MtlFunction(lib, "add_arrays")
pip_addfun = MtlComputePipelineState(dev, fun)
queue = global_queue(dev) #MtlCommandQueue(dev)

##
vecA .= 0.0; vecB .= 0.0; vecC .= 0.0;
cmd = MetalCore.commit!(queue) do cmdbuf
    MtlComputeCommandEncoder(cmdbuf) do enc
        MetalCore.set_function!(enc, pip_addfun)
        MetalCore.set_buffer!(enc, bufferA.buffer, 0, 1)
        MetalCore.set_buffer!(enc, bufferB.buffer, 0, 2)
        MetalCore.set_buffer!(enc, bufferC.buffer, 0, 3)
        #MetalCore.set_buffers!(enc,
        #                        [bufferA.buffer, bufferB.buffer, bufferC.buffer],
        #                        [0,0,0], 1:3)
        gridSize = MtSize(length(vecA), 1, 1)
        threadGroupSize = min(length(vecA), pip_addfun.maxTotalThreadsPerThreadgroup)
        threadGroupSize = MetalCore.MtSize(threadGroupSize, 1, 1)
        @info threadGroupSize
        MetalCore.append_current_function!(enc, gridSize, threadGroupSize)
    end
end

# Execute
wait(cmd)

@show vecC
