using UnitaryPruning
"""
    involutory_transformation(o::PauliString{N}, g::PauliString{N}, t) where N

Evaluate the unitary transformation of `o` by the unitary generated by `g`: 

i.e. for the case where `o` and `g` don't commute:
```math
\\bar{\\hat{o}} = e^{it\\hat{g}}\\hat{o}e^{-it\\hat{g}} = cos(2t)\\hat{o} + i\\sin(2t)[\\hat{g}, \\hat{o}]
```
"""
function involutory_transformation(o::PauliString{N}, g::PauliString{N}, t) where N

end

function dfs(ham_ops, ham_par, ansatz_ops, ansatz_par, thresh)
    o = ham_ops[2]
    g = ansatz_ops[1]
    print(o)
    print(g)
    println(commute(o,g))
end

function compute_expectation_value_recurse(ref_state, ham_ops, ham_par, ansatz_ops, ansatz_par; thresh=1e-8, max_depth=4)

    e_hf = 0.0
    energy = [0.0]
    for hi in 1:length(ham_ops)
        ei = expectation_value_sign(ham_ops[hi], ref_state) * ham_par[hi] 
        #if is_diagonal(ham_ops[hi])
        #    @printf("%20s %12.8f %12.8f\n", string(ham_ops[hi]), ei, ham_par[hi])
        #end
        e_hf += ei
        build_binary_tree!(ref_state, energy, ham_ops[hi], ham_par[hi], ansatz_ops, ansatz_par, thresh=thresh, max_depth=max_depth)
    end
    println(e_hf)
    println(energy)
       
end

function compute_expectation_value_iter(ref_state, ham_ops, ham_par, ansatz_ops, ansatz_par; thresh=1e-8, max_depth=4)

    e_hf = 0.0
    energy = [0.0]
    for hi in 1:length(ham_ops)
        ei = expectation_value_sign(ham_ops[hi], ref_state) * ham_par[hi] 
        #if is_diagonal(ham_ops[hi])
        #    @printf("%20s %12.8f %12.8f\n", string(ham_ops[hi]), ei, ham_par[hi])
        #end
        e_hf += ei
        iterate_dfs!(ref_state, energy, ham_ops[hi], ham_par[hi], ansatz_ops, ansatz_par, thresh=thresh, max_depth=max_depth)
    end
    println(e_hf)
    println(energy)
       
end

function build_binary_tree!(ref_state, energy::Vector{Float64}, o::PauliString{N}, h, ansatz_ops::Vector{PauliString{N}}, ansatz_par; thresh=1e-12, max_depth=3) where N
    #={{{=#
    ansatz_layer = 1
    depth = 0

    pauli_I = PauliString(N)

    vcos = cos.(2 .* ansatz_par)
    vsin = sin.(2 .* ansatz_par)


    return _recurse(ref_state, energy, pauli_I, o, h, thresh, ansatz_layer, depth, ansatz_ops, vcos, vsin, max_depth)
end
#=}}}=#


function _recurse(ref_state, energy::Vector{Float64}, pauli_I, o, h, thresh::Float64, ansatz_layer::Int, depth::Int, ansatz_ops, vcos, vsin, max_depth)
    #={{{=#
    if ansatz_layer == length(ansatz_ops)+1
        _find_leaf_no_branching(ref_state, energy, o, h )
    elseif abs(h) < thresh
        _find_leaf_no_branching(ref_state, energy, o, h )
    #elseif depth > max_depth
    #    _find_leaf_no_branching(ref_state, energy, o, h )
    else

        g = ansatz_ops[ansatz_layer]
        if commute(g,o)
            _recurse(ref_state, energy, pauli_I, o, h, thresh, ansatz_layer+1, depth, ansatz_ops, vcos, vsin, max_depth)
        else
            phase, or = commutator(g, o)
            if 1==0
                @btime commutator($g, $o)
                error("here")
            end
            real(phase) == 0 || error("why is phase not imaginary?", phase)
            hr = real(1im*phase) * h * vsin[ansatz_layer]
            #hr = 0.5*real(1im*phase) * h * vsin[ansatz_layer]

            # left branch
            ol = o
            hl = h * vcos[ansatz_layer]

            _recurse(ref_state, energy, pauli_I, ol, hl, thresh, ansatz_layer+1, depth, ansatz_ops, vcos, vsin, max_depth)
            _recurse(ref_state, energy, pauli_I, or, hr, thresh, ansatz_layer+1, depth+1, ansatz_ops, vcos, vsin, max_depth)
        end

    end
end
#=}}}=#


function _recurse_old(ref_state, energy::Vector{Float64}, pauli_I, o, h, thresh::Float64, ansatz_layer::Int, depth::Int, ansatz_ops, vcos, vsin, max_depth)
  #={{{=#
    if ansatz_layer == length(ansatz_ops)+1
        # found a leaf
       
        # compute energy. Currently, we are only considering product states in the z basis
        if is_diagonal(o)
            sign = expectation_value_sign(o, ref_state) 

            #@printf(" Found energy contribution %12.8f at ansatz layer %5i and depth %5i\n", sign*h, ansatz_layer, depth)
            energy[1] += sign*h
        end
        return 
    end

    #
    # does o need to be transformed by g? Only if a) they don't commute and b) sin(2t)*h > thresh and c) depth < max_depth
    #
    g = ansatz_ops[ansatz_layer]

    #if (depth < max_depth) && (commute(g,o) == false) && (abs(vsin[ansatz_layer]*h) > thresh)
    if 1==0
        @btime commute($g, $o)
        error("here")
    end
    if commute(g,o) == false
        if depth < max_depth
            if abs(vsin[ansatz_layer]*h) > thresh
                # please transform

                # right branch
                phase, or = commutator(g, o)
                if 1==0
                    @btime commutator($g, $o)
                    error("here")
                end
                real(phase) == 0 || error("why is phase not imaginary?", phase)
                hr = real(1im*phase) * h * vsin[ansatz_layer]
                #hr = 0.5*real(1im*phase) * h * vsin[ansatz_layer]

                # left branch
                ol = o
                hl = h * vcos[ansatz_layer]

                _recurse(ref_state, energy, pauli_I, ol, hl, thresh, ansatz_layer+1, depth, ansatz_ops, vcos, vsin, max_depth)
                _recurse(ref_state, energy, pauli_I, or, hr, thresh, ansatz_layer+1, depth+1, ansatz_ops, vcos, vsin, max_depth)
            else
                # found a leaf
                #_recurse(ref_state, energy, pauli_I, o, h, thresh, ansatz_layer+1, depth, ansatz_ops, vcos, vsin, max_depth)
                #_recurse(ref_state, energy, pauli_I, o, h*vcos[ansatz_layer], thresh, ansatz_layer+1, depth, ansatz_ops, vcos, vsin, max_depth)
                _find_leaf_no_branching(ref_state, energy, o, h )
            end
        else
            # found a leaf
            #_recurse(ref_state, energy, pauli_I, o, h, thresh, ansatz_layer+1, depth, ansatz_ops, vcos, vsin, max_depth)
            #_recurse(ref_state, energy, pauli_I, o, h*vcos[ansatz_layer], thresh, ansatz_layer+1, depth, ansatz_ops, vcos, vsin, max_depth)
            _find_leaf_no_branching(ref_state, energy, o, h )
        end
    else
        # please continue to next operator in ansatz
        _recurse(ref_state, energy, pauli_I, o, h, thresh, ansatz_layer+1, depth, ansatz_ops, vcos, vsin, max_depth)
    end
end
#=}}}=#


function _find_leaf_no_branching(ref_state, energy::Vector{Float64}, o, h )
#={{{=#
    if is_diagonal(o)
        sign = expectation_value_sign(o, ref_state) 

        #@printf(" Found energy contribution %12.8f at ansatz layer %5i and depth %5i\n", sign*h, ansatz_layer, depth)
        energy[1] += sign*h
    end
end
#=}}}=#


function iterate_dfs!(ref_state, energy::Vector{Float64}, o::PauliString{N}, h, ansatz_ops::Vector{PauliString{N}}, ansatz_par; thresh=1e-12, max_depth=3) where N
#={{{=#
    vcos = cos.(2 .* ansatz_par)
    vsin = sin.(2 .* ansatz_par)
    depth = 0
   
    #ori = PauliString(N)

    stack = Stack{Tuple{PauliString{N},Float64,Int}}()  
    push!(stack, (o,h,1)) 

    while length(stack) > 0
        oi, hi, ansatz_layer = pop!(stack)
    
        if ansatz_layer == length(ansatz_ops)+1
            _find_leaf_no_branching(ref_state, energy, oi, hi )
        elseif abs(hi) < thresh
            _find_leaf_no_branching(ref_state, energy, oi, hi )
        else
            g = ansatz_ops[ansatz_layer]
            if commute(g,oi)
                push!(stack, (oi, hi, ansatz_layer+1))
            else
                #if depth < max_depth
                #if abs(vsin[ansatz_layer]*h) > thresh

                # right branch
                #@btime  commutator!($g, $oi, $or)
                #@code_warntype  commutator(g, oi)
                #error("here")
                
                #phase = commutator!(g, oi, ori)
                #phase2, or2 = commutator(g, oi)
                #phase2 == phase || error(" phase:", phase2, phase)
                #or2 == ori || error(" ori:", g, oi, or2, ori)
                
                phase, or = commutator(g, oi)
                hr = real(1im*phase) * hi * vsin[ansatz_layer]
                #hr = 0.5*real(1im*phase) * hi * vsin[ansatz_layer]

                push!(stack, (or, hr, ansatz_layer+1))

                # left branch
                hl = hi * vcos[ansatz_layer]
                push!(stack, (oi, hl, ansatz_layer+1))
            end
        end
    end
end
#=}}}=#


