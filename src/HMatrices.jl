module HMatrices

using StaticArrays
using LinearAlgebra
using Statistics: median
using ComputationalResources
using LoopVectorization
using TimerOutputs
using Printf
using RecipesBase
using WavePropBase
using WavePropBase.Trees
using WavePropBase.Utils

import AbstractTrees

include("utils.jl")
include("blockarray.jl")
include("hilbertcurve.jl")
include("kernelmatrix.jl")
include("rkmatrix.jl")
include("compressor.jl")
include("hmatrix.jl")
include("conversions.jl")
include("addition.jl")
include("multiplication.jl")
include("inverse.jl")
include("triangular.jl")
include("lu.jl")

export
    # modules (re-exported)
    Utils,
    # types (re-exported)
    ClusterTree,
    CardinalitySplitter,
    DyadicSplitter,
    GeometricSplitter,
    GeometricMinimalSplitter,
    HyperRectangle,
    # types
    HMatrix,
    StrongAdmissibilityStd,
    PartialACA,
    ACA,
    TSVD,
    # functions
    compression_ratio,
    print_tree,
    hmul!

end
