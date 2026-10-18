(module
  ;; WebAssembly does not have random number generation built-in, so we will
  ;; write our own using the Xorshift algorithm.

  ;; Random number generator state
  (global $rng_state (mut i32) (i32.const 127))

  (func $set_seed (param $seed i32)
    ;; The seed cannot be zero.

    ;; options
    i32.const 127         ;; used when cond == 1
    local.get $seed       ;; used when cond == 0

    ;; cond
    local.get $seed
    i32.eqz               ;; pushes 1 onto the stack if seed == 0 and 0 otherwise     
    
    ;; ternary operator
    select                ;; cond==1 → 127; cond==0 → seed

    global.set $rng_state
  )

  ;; Xorshift algorithm:
  ;;     x = rng_state
  ;;     x ^= x << 13
  ;;     x ^= x >> 17
  ;;     x ^= x << 5
  ;;     rng_state = x
  (func $rand (result i32)
    (local $x i32)

    ;; x = rng_state
    global.get $rng_state
    local.tee $x           ;; copy without popping

    ;; x = x ^ (x << 13)
    local.get $x           ;; keep two copies of $x on top of the stack
    i32.const 13
    i32.shl
    i32.xor
    local.tee $x

    ;; x = x ^ (x >>> 17)  (logical right shift)
    local.get $x
    i32.const 17
    i32.shr_u              ;; doesn't preserve sign
    i32.xor
    local.tee $x

    ;; x = x ^ (x << 5)
    local.get $x
    i32.const 5
    i32.shl
    i32.xor
    local.tee $x

    ;; rng_state = x
    local.get $x
    global.set $rng_state

    ;; There are still one copy of $x on the stack to return
  )

  ;; For this project, we need a function that returns a random floating-point 
  ;; number in the range [0, 1).
  (func $randf (result f64)
    call $rand
    f64.convert_i32_u
    f64.const 4294967296.0  ;; 2^32
    f64.div
  )

  ;; WebAssembly does not have a built-in sine function, so we will implement it
  ;; ourselves using Horner's method for the Taylor series expansion with hardcoded
  ;; coefficients.
  ;;     sin x ≈ x * (1 - 1/6 * x^2 * (1 - 1/20 * x^2 * (1 - 1/42 * x^2)))
  (func $sin (param $x f64) (result f64)
    (local $x2 f64)  ;; store x^2 for reuse
    
    local.get $x
    local.get $x
    f64.mul
    local.tee $x2             ;; copy without popping
    
    ;; innermost term: (1 - 1/42 * x^2)
    f64.const -0.0238095238   ;; ≈ -1/42
    f64.mul                   ;; - 1/42 * x^2
    f64.const 1.0
    f64.add                   ;; 1 - 1/42 * x^2

    ;; middle term: (1 - 1/20 * x^2 * (...))
    f64.const -0.05           ;; -1/20
    local.get $x2
    f64.mul                   ;; -1/20 * x^2 
    f64.mul                   ;; -1/20 * x^2 * (1 - 1/42 * x^2)
    f64.const 1.0
    f64.add                   ;; 1 - 1/20 * x^2 * (1 - 1/42 * x^2)

    ;; outermost term: (1 - 1/6 * x^2 * (...))
    f64.const -0.16666666667  ;; ≈ -1/6
    local.get $x2
    f64.mul                   ;; -1/6 * x^ 2 
    f64.mul                   ;; -1/6 * x^ 2 * (1 - 1/20 * x^2 * (1 - 1/42 * x^2))
    f64.const 1.0
    f64.add                   ;; 1 - 1/6 * x^ 2 * (1 - 1/20 * x^2 * (1 - 1/42 * x^2))

    ;; multiply by x to get the final sine value
    local.get $x
    f64.mul
  )

  (func $run_simulation (param $throws i32) (result f64)
    (local $hits i32)  ;; holds the number of times the needle crossed a line
    (local $i i32)  ;; loop counter

    (loop $main
      ;; randomly select a position fo the center of the needle
      call $randf
      f64.const 0.5
      f64.mul

      ;; randomly select an angle for the needle and compute the distance
      ;; to the nearest line
      call $randf
      f64.const 1.5707963267948966  ;; π/2
      f64.mul
      call $sin
      f64.const 0.5
      f64.mul

      ;; compare both values and update the hit count
      f64.le           ;; pushes 1 to the stack if x <= sin(θ)/2, 0 otherwise
      local.get $hits
      i32.add
      local.set $hits  ;; branchless update

      ;; increment loop counter
      local.get $i
      i32.const 1
      i32.add
      local.tee $i  ;; copy without popping

      ;; keep while i < $throws
      local.get $throws
      i32.lt_u
      br_if $main
    )

    ;; --- Compute pi ---
    ;; numerator: 2 * $throws
    local.get $throws
    f64.convert_i32_u
    f64.const 2.0
    f64.mul
    ;; denominator: $hits
    local.get $hits
    f64.convert_i32_u
    f64.div
  )

  (export "set_seed" (func $set_seed))
  (export "run_simulation" (func $run_simulation))
)