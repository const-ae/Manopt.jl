### A Pluto.jl notebook ###
# v0.17.2

using Markdown
using InteractiveUtils

# ╔═╡ 856f336c-e232-4f1f-b1ac-759b4558acd1
using Manifolds, Manopt, Random, LinearAlgebra

# ╔═╡ b0769dfa-28cf-440e-9ba2-1ef488f171a9
using FiniteDiff, ReverseDiff

# ╔═╡ 0213d26a-18ac-11ec-03fd-ada5992bcea8
md"""
# Using (Euclidean) AD in Manopt.jl
"""

# ╔═╡ f3bc91ee-5871-4cba-ac89-190deb71ad0f
md"""
Since [Manifolds.jl](https://juliamanifolds.github.io/Manifolds.jl/latest/) 0.7 the support of automatic differentiation support has been extended.

This tutorial explains how to use Euclidean tools to derive a gradient for a real-valued function ``F\colon \mathcal M → ℝ``. We will consider two methods: an intrinsic variant and a variant employing the embedding. These gradients can then be used within any gradient based optimisation algorithm in [Manopt.jl](https://manoptjl.org).

While by default we use [FiniteDifferences.jl](https://juliadiff.org/FiniteDifferences.jl/latest/), you can also use [FiniteDiff.jl](https://github.com/JuliaDiff/FiniteDiff.jl), [ForwardDiff.jl](https://juliadiff.org/ForwardDiff.jl/stable/), [ReverseDiff.jl](https://juliadiff.org/ReverseDiff.jl/), or  [Zygote.jl](https://fluxml.ai/Zygote.jl/).
"""

# ╔═╡ d9be6c2f-65fd-4685-9005-da22bf985e28
md"""
In this Notebook we will take a look at a few possibilities to approximate or derive the gradient of a function ``f:\mathcal M \to ℝ`` on a Riemannian manifold, without computing it yourself. There is mainly two different philosophies:

1. Working _instrinsically_, i.e. stay on the manifold and in the tangent spaces. Here, we will consider approximating the gradient by forward differences.

2. Working in an embedding – there we can use all tools from functions on Euclidean spaces – finite differences or automatic differenciation – and then compute the corresponding Riemannian gradient from there.

Let's first load all packages we need.
"""

# ╔═╡ 18d7459f-eed6-489b-a096-ac77ccd781af
md"""
## 1. (Intrinsic) Forward Differences

A first idea is to generalise (multivariate) finite differences to Riemannian manifolds. Let ``X_1,\ldots,X_d ∈ T_p\mathcal M`` denote an orthonormal basis of the tangent space ``T_p\mathcal M`` at the point ``p∈\mathcal M`` on the Riemannian manifold.

We can generalise the notion of a directional derivative, i.e. for the “direction” ``Y∈T_p\mathcal M`` let ``c\colon [-ε,ε]``, ``ε>0``, be a curve with ``c(0) = p``, ``\dot c(0) = Y`` and we obtain

```math
	Df(p)[Y] = \frac{\mathrm{d}}{\mathrm{d}t} f(c(t)) = \lim_{h \to 0} \frac{1}{h}(f(\exp_p(hY))-f(p))
```

We can approximate ``Df(p)[X]`` by a finite difference scheme for an ``h>0`` as

```math
DF(p)[Y] ≈ G_h(Y) := \frac{1}{h}(f(\exp_p(hY))-f(p))
```

Furthermore the gradient ``\operatorname{grad}f`` is the Riesz representer of the differential, ie.

```math
	Df(p)[Y] = g_p(\operatorname{grad}f(p), Y),\qquad \text{ for all } Y ∈ T_p\mathcal M
```

and since it is a tangent vector, we can write it in terms of a basis as

```math
	\operatorname{grad}f(p) = \sum_{i=1}^{d} g_p(\operatorname{grad}f(p),X_i)X_i
	= \sum_{i=1}^{d} Df(p)[X_i]X_i
```

and perform the approximation from above to obtain
```math
	\operatorname{grad}f(p) ≈ \sum_{i=1}^{d} G_h(X_i)X_i
```
for some suitable step size ``h``.This comes at the cost of ``d+1`` function evaluations and ``d`` exponential maps.
"""

# ╔═╡ a3df142e-94df-48d2-be08-d1f1f3854c76
md"""
This is the first variant we can use. An advantage is, that it is _intrinsic_ in the sense that it does not require any embedding of the manifold.
"""

# ╔═╡ 9a030ac6-1f44-4fa6-8bc9-1c0278e97fe2
md""" ### An Example: The Rayleigh Quotient

The Rayleigh quotient is concerned with finding Eigenvalues (and Eigenvectors) of a symmetric matrix $A\in ℝ^{(n+1)×(n+1)}$. The optimisation problem reads

```math
F\colon ℝ^{n+1} \to ℝ,\quad F(\mathbf x) = \frac{\mathbf x^\mathrm{T}A\mathbf x}{\mathbf x^\mathrm{T}\mathbf x}
```

Minimizing this function yields the smallest eigenvalue ``\lambda_1`` as a value and the corresponding minimizer ``\mathbf x^*`` is a corresponding eigenvector.

Since the length of an eigenvector is irrelevant, there is an ambiguity in the cost function. It can be better phrased on the sphere ``𝕊^n`` of unit vectors in ``\mathbb R^{n+1}``, i.e.

```math
\operatorname*{arg\,min}_{p \in 𝕊^n} f(p) = \operatorname*{arg\,min}_{p \in 𝕊^n} p^\mathrm{T}Ap
```

We can compute the Riemannian gradient exactly as

```math
\operatorname{grad} f(p) = 2(Ap - pp^\mathrm{T}Ap)
```

so we can compare it to the approximation by finite differences.
"""

# ╔═╡ 19747159-d383-4547-9315-0ed2494904a6
begin
    Random.seed!(42)
    n = 200
    A = randn(n + 1, n + 1)
    A = Symmetric(A)
    M = Sphere(n)
    nothing
end

# ╔═╡ 41c204dd-6e4e-4a70-8f06-209a469e0680
f1(p) = p' * A'p

# ╔═╡ 2e33de5e-ffaa-422a-91d9-61f588ed1211
gradf1(p) = 2 * (A * p - p * p' * A * p)

# ╔═╡ bbd9a010-1981-45b3-bf7d-c04bcd2c2128
md"""Manifolds provides a finite difference scheme in Tangent spaces, that you can introduce to use an existing framework (if the wrapper is implemented) form Euclidean space. Here we use `FiniteDiff.jl`."""

# ╔═╡ 08456b40-74ec-4319-93e7-130b5cf70ac3
r_backend = Manifolds.TangentDiffBackend(Manifolds.FiniteDiffBackend())

# ╔═╡ 12327b62-7e79-4381-b6a7-f85b08a8251b
gradf1_FD(p) = Manifolds.gradient(M, f1, p, r_backend)

# ╔═╡ 07f9a630-e53d-45ea-b109-3d4de190723d
begin
    p = zeros(n + 1)
    p[1] = 1.0
    X1 = gradf1(p)
    X2 = gradf1_FD(p)
    norm(M, p, X1 - X2)
end

# ╔═╡ 8e5f677d-dafa-49b9-b678-3f129be31dcf
md"We obtain quite a good approximation of the gradient."

# ╔═╡ 77769eab-54dd-41dc-8125-0382e5ef0bf1
md"""
## 2. Conversion of an Euclidean Gradient in the Embedding to a Riemannian Gradient of an (not necessarily isometrically) embedded Manifold

Let ``\tilde f\colon\mathbb R^m \to \mathbb R`` be a function in the embedding of an ``n``-dimensional manifold ``\mathcal M \subset \mathbb R^m`` and ``f\colon \mathcal M \to \mathbb R`` denote the restriction of ``\tilde f`` to the manifold ``\mathcal M``.

Since we can use the push forward of the embedding to also embed the tangent space ``T_p\mathcal M``, ``p\in \mathcal M``, we can similarly obtain the differential ``Df(p)\colon T_p\mathcal M \to \mathbb R`` by restricting the differential ``D\tilde f(p)`` to the tangent space.

If both ``T_p\mathcal M`` and ``T_p\mathcal R^m`` have the same inner product, or in other words the manifold is isometrically embedded in ``R^m`` (like for example the sphere ``\mathbb S^n\subset\mathbb R^{m+1}`` then this restriction of the differential directly translates to a projection of the gradient, i.e.

```math
\operatorname{grad}f(p) = \operatorname{Proj}_{T_p\mathcal M}(\operatorname{grad} \tilde f(p))
```

More generally we might have to take a change of the metric into account, i.e.

```math
\langle  \operatorname{Proj}_{T_p\mathcal M}(\operatorname{grad} \tilde f(p)), X \rangle
= Df(p)[X] = g_p(\operatorname{grad}f(p), X)
```

or in words: we have to change the Riesz representer of the (restricted/projected) differential of ``f`` (``\tilde f``) to the one with respect to the Riemannian metric. This is done using [`change_representer`](https://juliamanifolds.github.io/Manifolds.jl/latest/manifolds/metric.html#Manifolds.change_representer-Tuple{AbstractManifold,%20AbstractMetric,%20Any,%20Any}).
"""

# ╔═╡ 57cda07f-e432-46af-b771-5e5a3067feac
md"""
### A continued Example
We continue with the Rayleigh Quotient from before, now just starting with the defintion of the Euclidean case in the embedding, the function ``F``.
"""

# ╔═╡ c3f3aeba-2849-4715-94e2-0c44613a2ce9
F(x) = x' * A * x / (x' * x);

# ╔═╡ 786fce04-53ef-448d-9657-31208b35fb7e
md"The cost function is the same by restriction"

# ╔═╡ c1341fef-adec-4574-a642-a1a8a9c1fee5
f2(M, p) = F(p);

# ╔═╡ 0818a62f-1bef-44f7-a33f-1ab0054e853c
md"The gradient is now computed combining our gradient scheme with ReverseDiff."

# ╔═╡ 89cd6b4b-f9ef-47ac-afd3-cf9aacf43256
function grad_f2_AD(M, p)
    return Manifolds.gradient(
        M, F, p, RiemannianProjectionBackend(Manifolds.ReverseDiffBackend())
    )
end

# ╔═╡ 7c5a8a17-6f63-4587-a94a-6936bdd3cec6
X3 = grad_f2_AD(M, p)

# ╔═╡ b3e7f57f-d87a-47c5-b8ad-48b6d205fa73
norm(M, p, X1 - X3)

# ╔═╡ 893db402-283f-4e3e-8bf7-c6f22e485efb
md"""
### An Example for a nonisometrically embedded Manifold

on the manifold ``\mathcal P(3)`` of symmetric positive definite matrices.
"""

# ╔═╡ 8494a0d6-dbf2-4eb0-a555-f00e446fbe38
md"""
The following function computes (half) the distance squared (with respect to the linear affine metric) on the manifold ``\mathcal P(3)`` to the identity, i.e. $I_3$. denoting the unit matrix we consider the function

```math
	G(q) = \frac{1}{2}d^2_{\mathcal P(3)}(q,I_3) = \lVert \operatorname{Log}(q) \rVert_F^2,
```
where $\operatorname{Log}$ denotes the matrix logarithm and ``\lVert \cdot \rVert_F`` is the Frobenius norm.
This can be computed for symmetric positive definite matrices by summing the squares of the ``\log``arithms of the eigenvalues of ``q`` and divide by two:
"""

# ╔═╡ c93eb2da-89df-4751-b086-62be604d41e6
G(q) = sum(log.(eigvals(Symmetric(q))) .^ 2) / 2

# ╔═╡ e2bf6f55-7235-4d75-8bee-a325434e32ad
md"""
We can also interpret this as a function on the space of matrices and apply the Euclidean finite differences machinery; in this way we can easily derive the Euclidean gradient. But when computing the Riemannian gradient, we have to change the representer (see again [`change_representer`](https://juliamanifolds.github.io/Manifolds.jl/latest/manifolds/metric.html#Manifolds.change_representer-Tuple{AbstractManifold,%20AbstractMetric,%20Any,%20Any})) after projecting onto the tangent space ``T_p\mathcal P(n)`` at ``p``.

Let's first define a point and the manifold ``N=\mathcal P(3)``.
"""

# ╔═╡ 153378ca-703d-4a84-bc63-22347399a160
rotM(α) = [1.0 0.0 0.0; 0.0 cos(α) sin(α); 0.0 -sin(α) cos(α)]

# ╔═╡ 699f0177-2c5b-434b-9eca-b6fc573e497f
q = rotM(π / 6) * [1.0 0.0 0.0; 0.0 2.0 0.0; 0.0 0.0 3.0] * transpose(rotM(π / 6))

# ╔═╡ 9b52d05c-4cba-4922-85a4-1a2a3c74823e
N = SymmetricPositiveDefinite(3)

# ╔═╡ cb3fe7aa-1262-48f2-9ebc-3e959c72a33e
is_point(N, q)

# ╔═╡ 13712c64-48fd-4f2a-9ee4-1949e51d316f
md"""We could first just compute the gradient using `FiniteDiff.jl`, but this yields the Euclidean gradient:"""

# ╔═╡ 64beb3dd-9507-4792-be02-ae1405704690
FiniteDiff.finite_difference_gradient(G, q)

# ╔═╡ 2be4f9e8-0331-44ac-839f-7bb71d9edef9
md"""Instead, we use the [`RiemannianProjectedBackend`](https://juliamanifolds.github.io/Manifolds.jl/latest/features/differentiation.html#Manifolds.RiemannianProjectionBackend) of `Manifolds.jl`, which in this case internally uses `FiniteDiff.jl` to compute a Euclidean gradient but then uses the conversion explained above to derive the Riemannian gradient.

We define this here again as a function `grad_G_FD` that could be used in the `Manopt.jl` framework within a gradient based optimisation.
"""

# ╔═╡ 6f1d748f-27ce-496b-8561-f16972da50cc
function grad_G_FD(N, q)
    return Manifolds.gradient(
        N, G, q, RiemannianProjectionBackend(Manifolds.FiniteDiffBackend())
    )
end

# ╔═╡ 7dd656ea-08de-4172-8a92-87ad2228ce69
G1 = grad_G_FD(N, q)

# ╔═╡ 219573d2-283f-456c-a5c3-fadd734fc157
md"""
Now, we can agaon compare this to the (known) solution of the gradient, namely the gradient of (a half) the distance suqared, i.e. ``G(q) = \frac{1}{2}d^2_{\mathcal P(3)}(q,I_3)`` is given by ``\operatorname{grad} G(q) = -\operatorname{log}_q I_3``, where ``\operatorname{log}`` is the [logarithmic map](https://juliamanifolds.github.io/Manifolds.jl/latest/manifolds/symmetricpositivedefinite.html#Base.log-Tuple{SymmetricPositiveDefinite,%20Vararg{Any,%20N}%20where%20N}) on the manifold.
"""

# ╔═╡ e28a2752-877c-4ab4-a253-8d26fa9a73c2
G2 = -log(N, q, Matrix{Float64}(I, 3, 3))

# ╔═╡ 25c65878-1be6-4fec-b65e-9c1741320a41
md"""Both terms agree up to ``1.2×10^{-10}``:"""

# ╔═╡ 9a66d4f3-508d-4285-9a93-df1323575202
norm(G1 - G2)

# ╔═╡ c07fb3d0-d12f-44d7-bcab-7a0d39e6af8d
isapprox(M, q, G1, G2; atol=2 * 1e-10)

# ╔═╡ f47c70b6-ca05-498f-9e10-58c3839ca427
md""" In this case we can not use `ReverseDiff.jl`, since it can not handle the `eigvals!` function that is called internally."""

# ╔═╡ 32d8d025-3993-4d31-9eea-3463e0af1c12
md"""
## Summary

This tutorial illustrates how to use tools from Euclidean spaces, finite differences or automatic differentiation, to compute gradients on Riemannian manifolds. The scheme allows to use _any_ differentiation framework within the embedding to derive a Riemannian gradient.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
FiniteDiff = "6a86dc24-6348-571c-b903-95158fe2bd41"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Manifolds = "1cead3c2-87b3-11e9-0ccd-23c62b72b94e"
Manopt = "0fc0a36d-df90-57f3-8f93-d78a9fc72bb5"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"

[compat]
FiniteDiff = "~2.8.1"
Manifolds = "~0.7.1"
Manopt = "~0.3.14"
ReverseDiff = "~1.10.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0"
manifest_format = "2.0"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "485ee0867925449198280d4af84bdb46a2a404d0"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.0.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "62e51b39331de8911e4a7ff6f5aaf38a5f4cc0ae"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.2.0"

[[deps.ArrayInterface]]
deps = ["Compat", "IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "265b06e2b1f6a216e0e8f183d28e4d354eab3220"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "3.2.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "f885e7e7c124f8c92650d61b9477b9ac2ee607dd"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.11.1"

[[deps.ChangesOfVariables]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "9a1d594397670492219635b35a3d830b04730d62"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.1"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "a851fec56cb73cfdf43762999ec72eff5b86882a"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.15.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "dce3e3fea680869eaa0b774b2e8343e9ff442313"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.40.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.CovarianceEstimation]]
deps = ["LinearAlgebra", "Statistics", "StatsBase"]
git-tree-sha1 = "bc3930158d2be029e90b7c40d1371c4f54fa04db"
uuid = "587fd27a-f159-11e8-2dae-1979310e6154"
version = "0.2.6"

[[deps.DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[deps.DiffRules]]
deps = ["LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "d8f468c5cd4d94e86816603f7d18ece910b4aaf1"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.5.0"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "7f3bec11f4bcd01bc1f507ebce5eadf1b0a78f47"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.34"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.Einsum]]
deps = ["Compat"]
git-tree-sha1 = "4a6b3eee0161c89700b6c1949feae8b851da5494"
uuid = "b7d42ee7-0b51-5a75-98ca-779d3107e4c0"
version = "0.4.1"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "8756f9935b7ccc9064c6eef0bff0ad643df733a3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.12.7"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "8b3c09b56acaf3c0e581c66638b85c8650ee9dca"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.8.1"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "6406b5112809c08b1baa5703ad274e1dded0652f"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.23"

[[deps.FunctionWrappers]]
git-tree-sha1 = "241552bc2209f0fa068b6415b1942cc0aa486bcc"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.2"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "92243c07e786ea3458532e199eb3feee0e7e08eb"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.4.1"

[[deps.HybridArrays]]
deps = ["LinearAlgebra", "Requires", "StaticArrays"]
git-tree-sha1 = "c1d5b1dcdf2140644e1c6beb9ca09fbed601c241"
uuid = "1baab800-613f-4b0a-84e4-9cd3431bfbb9"
version = "0.4.9"

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.Inflate]]
git-tree-sha1 = "f5fc07d4e706b84f72d54eedcc1c13d92fb0871c"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "a7254c0acd8e62f1ac75ad24d5db43f5f19f3c65"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.2"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[deps.Kronecker]]
deps = ["LinearAlgebra", "NamedDims", "SparseArrays", "StatsBase"]
git-tree-sha1 = "a51f46415c844dee694cb8b20a3fcbe6dba342c2"
uuid = "2c470bb0-bcc8-11e8-3dad-c9649493f05e"
version = "0.5.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "be9eef9f9d78cecb6f262f3c10da151a6c5ab827"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.5"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Manifolds]]
deps = ["Colors", "Distributions", "Einsum", "Graphs", "HybridArrays", "Kronecker", "LinearAlgebra", "ManifoldsBase", "Markdown", "Random", "RecipesBase", "RecursiveArrayTools", "Requires", "SimpleWeightedGraphs", "SpecialFunctions", "StaticArrays", "Statistics", "StatsBase"]
git-tree-sha1 = "3811935fd2549b0f5f9b365d6e7173fcdb98ec9a"
uuid = "1cead3c2-87b3-11e9-0ccd-23c62b72b94e"
version = "0.7.1"

[[deps.ManifoldsBase]]
deps = ["LinearAlgebra", "Markdown"]
git-tree-sha1 = "77a5949567437d185ee929c405e3c6c0768118ea"
uuid = "3362f125-f0bb-47a3-aa74-596ffd7ef2fb"
version = "0.12.9"

[[deps.Manopt]]
deps = ["ColorSchemes", "ColorTypes", "Colors", "DataStructures", "Dates", "LinearAlgebra", "ManifoldsBase", "Markdown", "Random", "Requires", "SparseArrays", "StaticArrays", "Statistics", "Test"]
git-tree-sha1 = "e87c818e19f79444fff1c77880cdb43b51974dfe"
uuid = "0fc0a36d-df90-57f3-8f93-d78a9fc72bb5"
version = "0.3.14"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[deps.NamedDims]]
deps = ["AbstractFFTs", "ChainRulesCore", "CovarianceEstimation", "LinearAlgebra", "Pkg", "Requires", "Statistics"]
git-tree-sha1 = "4f34e3ff2fa7f2a1c03fb2c4fdd637380d760bbc"
uuid = "356022a1-0364-5f58-8944-0da4b18d706f"
version = "0.2.42"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "ee26b350276c51697c9c2d88a072b339f9f03d73"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.5"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[deps.RecursiveArrayTools]]
deps = ["ArrayInterface", "ChainRulesCore", "DocStringExtensions", "FillArrays", "LinearAlgebra", "RecipesBase", "Requires", "StaticArrays", "Statistics", "ZygoteRules"]
git-tree-sha1 = "c944fa4adbb47be43376359811c0a14757bdc8a8"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "2.20.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[deps.ReverseDiff]]
deps = ["ChainRulesCore", "DiffResults", "DiffRules", "ForwardDiff", "FunctionWrappers", "LinearAlgebra", "MacroTools", "NaNMath", "Random", "SpecialFunctions", "StaticArrays", "Statistics"]
git-tree-sha1 = "14b09b7d28378e6e8be334edc0ade781b5c65e85"
uuid = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
version = "1.10.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.SimpleWeightedGraphs]]
deps = ["Graphs", "LinearAlgebra", "Markdown", "SparseArrays", "Test"]
git-tree-sha1 = "a6f404cc44d3d3b28c793ec0eb59af709d827e4e"
uuid = "47aef6b3-ad0c-573a-a1e2-d07658019622"
version = "1.2.1"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "f0bccf98e16759818ffc5d97ac3ebf87eb950150"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.8.1"

[[deps.Static]]
deps = ["IfElse"]
git-tree-sha1 = "e7bc80dc93f50857a5d1e3c8121495852f407e6a"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.4.0"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3c76dde64d03699e074ac02eb2e8ba8254d428da"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.13"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
git-tree-sha1 = "0f2aa8e32d511f758a2ce49208181f7733a0936a"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.1.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "2bb0cb32026a66037360606510fca5984ccc6b75"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.13"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "bedb3e17cc1d94ce0e6e66d3afa47157978ba404"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.14"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.ZygoteRules]]
deps = ["MacroTools"]
git-tree-sha1 = "8c1a8e4dfacb1fd631745552c8db35d0deb09ea0"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.2"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─0213d26a-18ac-11ec-03fd-ada5992bcea8
# ╟─f3bc91ee-5871-4cba-ac89-190deb71ad0f
# ╟─d9be6c2f-65fd-4685-9005-da22bf985e28
# ╠═856f336c-e232-4f1f-b1ac-759b4558acd1
# ╠═b0769dfa-28cf-440e-9ba2-1ef488f171a9
# ╟─18d7459f-eed6-489b-a096-ac77ccd781af
# ╟─a3df142e-94df-48d2-be08-d1f1f3854c76
# ╟─9a030ac6-1f44-4fa6-8bc9-1c0278e97fe2
# ╠═19747159-d383-4547-9315-0ed2494904a6
# ╠═41c204dd-6e4e-4a70-8f06-209a469e0680
# ╠═2e33de5e-ffaa-422a-91d9-61f588ed1211
# ╟─bbd9a010-1981-45b3-bf7d-c04bcd2c2128
# ╠═08456b40-74ec-4319-93e7-130b5cf70ac3
# ╠═12327b62-7e79-4381-b6a7-f85b08a8251b
# ╠═07f9a630-e53d-45ea-b109-3d4de190723d
# ╟─8e5f677d-dafa-49b9-b678-3f129be31dcf
# ╟─77769eab-54dd-41dc-8125-0382e5ef0bf1
# ╟─57cda07f-e432-46af-b771-5e5a3067feac
# ╠═c3f3aeba-2849-4715-94e2-0c44613a2ce9
# ╟─786fce04-53ef-448d-9657-31208b35fb7e
# ╠═c1341fef-adec-4574-a642-a1a8a9c1fee5
# ╟─0818a62f-1bef-44f7-a33f-1ab0054e853c
# ╠═89cd6b4b-f9ef-47ac-afd3-cf9aacf43256
# ╠═7c5a8a17-6f63-4587-a94a-6936bdd3cec6
# ╠═b3e7f57f-d87a-47c5-b8ad-48b6d205fa73
# ╟─893db402-283f-4e3e-8bf7-c6f22e485efb
# ╟─8494a0d6-dbf2-4eb0-a555-f00e446fbe38
# ╠═c93eb2da-89df-4751-b086-62be604d41e6
# ╟─e2bf6f55-7235-4d75-8bee-a325434e32ad
# ╠═153378ca-703d-4a84-bc63-22347399a160
# ╠═699f0177-2c5b-434b-9eca-b6fc573e497f
# ╠═9b52d05c-4cba-4922-85a4-1a2a3c74823e
# ╠═cb3fe7aa-1262-48f2-9ebc-3e959c72a33e
# ╟─13712c64-48fd-4f2a-9ee4-1949e51d316f
# ╠═64beb3dd-9507-4792-be02-ae1405704690
# ╟─2be4f9e8-0331-44ac-839f-7bb71d9edef9
# ╠═6f1d748f-27ce-496b-8561-f16972da50cc
# ╠═7dd656ea-08de-4172-8a92-87ad2228ce69
# ╟─219573d2-283f-456c-a5c3-fadd734fc157
# ╠═e28a2752-877c-4ab4-a253-8d26fa9a73c2
# ╟─25c65878-1be6-4fec-b65e-9c1741320a41
# ╠═9a66d4f3-508d-4285-9a93-df1323575202
# ╠═c07fb3d0-d12f-44d7-bcab-7a0d39e6af8d
# ╟─f47c70b6-ca05-498f-9e10-58c3839ca427
# ╟─32d8d025-3993-4d31-9eea-3463e0af1c12
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002