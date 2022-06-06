"""
    @hprofile

A macro which
- resets the default `TimerOutputs.get_defaulttimer` to zero
- execute the code block
- print the profiling details

This is useful as a coarse-grained profiling strategy in `HMatrices`
to get a rough idea of where time is spent. Note that this relies on
`TimerOutputs` annotations manually inserted in the code.
"""
macro hprofile(block)
    return quote
        TimerOutputs.enable_debug_timings(HMatrices)
        reset_timer!()
        $(esc(block))
        print_timer()
    end
end

"""
    PermutedMatrix{K,T} <: AbstractMatrix{T}

Structured used to reprensent the permutation of a matrix-like object. The
original matrix is stored in the `data::K` field, and the permutations are
stored in `rowperm` and `colperm`.
"""
struct PermutedMatrix{K,T} <: AbstractMatrix{T}
    data::K # original matrix
    rowperm::Vector{Int}
    colperm::Vector{Int}
    function PermutedMatrix(orig,rowperm,colperm)
        K = typeof(orig)
        T = eltype(orig)
        new{K,T}(orig,rowperm,colperm)
    end
end
Base.size(M::PermutedMatrix) = size(M.data)

function Base.getindex(M::PermutedMatrix,i,j)
    ip = M.rowperm[i]
    jp = M.colperm[j]
    M.data[ip,jp]
end

"""
    hilbert_cartesian_to_linear(n,x,y)

Convert the cartesian indices `x,y` into a linear index `d` using a hilbert
curve of order `n`. The coordinates `x,y` range from `0` to `n-1`, and the
output `d` ranges from `0` to `n^2-1`.

See [https://en.wikipedia.org/wiki/Hilbert_curve](https://en.wikipedia.org/wiki/Hilbert_curve).
"""
function hilbert_cartesian_to_linear(n::Integer,x,y)
    @assert ispow2(n)
    @assert 0 ≤ x ≤ n-1
    @assert 0 ≤ y ≤ n-1
    d = 0
    s = n >> 1
    while s>0
        rx = (x & s) > 0
        ry = (y & s) > 0
        d += s^2*((3*rx)⊻ry)
        x,y = _rot(n,x,y,rx,ry)
        s = s >> 1
    end
    @assert 0 ≤ d ≤ n^2-1
    return d
end

"""
    hilbert_linear_to_cartesian(n,d)

Convert the linear index `0 ≤ d ≤ n^2-1` into the cartesian coordinates `0 ≤ x <
n-1` and `0 ≤ y ≤ n-1` on the Hilbert curve of order `n`.

See [https://en.wikipedia.org/wiki/Hilbert_curve](https://en.wikipedia.org/wiki/Hilbert_curve).
"""
function hilbert_linear_to_cartesian(n::Integer,d)
    @assert ispow2(n)
    @assert 0 ≤ d ≤ n^2-1
    x,y = 0,0
    s = 1
    while s<n
        rx = 1 & (d >> 1)
        ry = 1 & (d ⊻ rx)
        x,y = _rot(s,x,y,rx,ry)
        x +=  s*rx
        y +=  s*ry
        d = d >> 2
        s = s << 1
    end
    @assert 0 ≤ x ≤ n-1
    @assert 0 ≤ y ≤ n-1
    return x,y
end

# auxiliary function using in hilbert curve. Rotates the points x,y
function _rot(n,x,y,rx,ry)
    if ry == 0
        if rx == 1
            x = n-1 - x
            y = n-1 - y
        end
        x,y = y,x
    end
    return x,y
end

function hilbert_points(n::Integer)
    @assert ispow2(n)
    xx = Int[]
    yy = Int[]
    for d in 0:n^2-1
        x,y = hilbert_linear_to_cartesian(n,d)
        push!(xx,x)
        push!(yy,y)
    end
    xx,yy
end

"""
    build_sequence_partition(seq,nq,cost,nmax)

Partition the sequence `seq` into `nq` contiguous subsequences with a maximum of
cost of `nmax` per set. Note that if `nmax` is too small, this may not be
possible (see [`has_partition`](@ref)).
"""
function build_sequence_partition(seq,np,cost,cmax)
    acc = 0
    partition = [empty(seq) for _ in 1:np]
    k = 1
    for el in seq
        c = cost(el)
        acc += c
        if acc > cmax
            k += 1
            push!(partition[k],el)
            acc = c
            @assert k <= np "unable to build sequence partition. Value of  `cmax` may be too small."
        else
            push!(partition[k],el)
        end
    end
    return partition
end

"""
    find_optimal_cost(seq,nq,cost,tol)

Find an approximation to the cost of an optimal partitioning of `seq` into `nq`
contiguous segments. The optimal cost is the smallest number `cmax` such that
`has_partition(seq,nq,cost,cmax)` returns `true`.
"""
function find_optimal_cost(seq,np,cost=identity,tol=1)
    lbound = maximum(cost,seq) |> Float64
    ubound = sum(cost,seq)     |> Float64
    guess  = (lbound+ubound)/2
    while ubound - lbound ≥ tol
        if has_partition(seq,np,guess,cost)
            ubound = guess
        else
            lbound = guess
        end
        guess  = (lbound+ubound)/2
    end
    return ubound
end

"""
    find_optimal_partition(seq,nq,cost,tol=1)

Find an approximation to the optimal partition `seq` into `nq` contiguous
segments according to the `cost` function. The optimal partition is the one
which minimizes the maximum `cost` over all possible partitions of `seq` into
`nq` segments.

The generated partition is optimal up to a tolerance `tol`; for integer valued
`cost`, setting `tol=1` means the partition is optimal.
"""
function find_optimal_partition(seq,np,cost=(x)->1,tol=1)
    cmax = find_optimal_cost(seq,np,cost,tol)
    p = build_sequence_partition(seq,np,cost,cmax)
    return p
end


"""
    has_partition(v,np,cost,cmax)

Given a vector `v`, determine whether or not a partition into `np` segments is
possible where the `cost` of each partition does not exceed `cmax`.
"""
function has_partition(seq,np,cmax,cost=identity)
    acc = 0
    k   = 1
    for el in seq
        c = cost(el)
        acc += c
        if acc > cmax
            k += 1
            acc = c
            k > np && (return false)
        end
    end
    return true
end

"""
    disable_getindex()

Call this function to disable the `getindex` method on `AbstractHMatrix`. This
is useful to avoid performance pitfalls associated with linear algebra methods
falling back to a generic implementation which uses the `getindex` method.
Calling `getindex(H,i,j)` will error after calling this function.
"""
disable_getindex() = (ALLOW_GETINDEX[] = false)

"""
    enable_getindex()

The opposite of [`disable_getindex`](@ref).
"""
enable_getindex()  = (ALLOW_GETINDEX[] = true)