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
  ;; coefficients for the Taylor series expansion: 1/6, 1/20, 1/42
  ;;
  ;; Horner's method for sine: x * (1 - 1/6 * x^2 * (1 - 1/20 * x^2 * (1 - 1/42 * x^2)))
  ;;
  ;; 1/6  ≈ 0.16666666667
  ;; 1/20 ≈ 0.05
  ;; 1/42 ≈ 0.0238095238
  (func $sin (param $x f64) (result f64)
    ;; temporary variables
    (local $t1 f64)
    (local $t2 f64)
    (local $t3 f64)
    (local $x2 f64)  ;; store x^2 for reuse
    
    local.get $x
    local.get $x
    f64.mul
    local.set $x2
    
    ;; innermost term: (1 - 1/42 * x^2)
    f64.const 1.0
    local.get $x2
    f64.const 0.0238095238  ;; 1/42
    f64.mul
    f64.sub
    local.set $t1

    ;; middle term: (1 - 1/20 * x^2 * t1)
    f64.const 1.0
    f64.const 0.05  ;; 1/20
    local.get $x2
    local.get $t1
    f64.mul
    f64.mul
    f64.sub
    local.set $t2

    ;; outermost term: (1 - 1/6 * x^2 * t2)
    f64.const 1.0
    f64.const 0.16666666667  ;; 1/6
    local.get $x2
    local.get $t2
    f64.mul
    f64.mul
    f64.sub
    local.set $t3

    ;; multiply by x to get the final sine value
    local.get $x
    local.get $t3
    f64.mul
  )

  (export "set_seed" (func $set_seed))
  (export "rand" (func $rand))
  (export "randf" (func $randf))
  (export "sin" (func $sin))
)