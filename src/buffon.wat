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

  (export "set_seed" (func $set_seed))
  (export "rand" (func $rand))
)