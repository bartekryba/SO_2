# Concurrent Noteć Calculator (Współbieżny Szesnastkator Noteć)

A concurrent, thread-safe x86_64 assembly implementation of a Reverse Polish Notation (RPN) calculator operating on 64-bit hexadecimal numbers.

## Overview

**Noteć** is a stack-based calculator that can run N parallel instances simultaneously, each in its own thread. The calculator uses the processor's hardware stack for computations and implements thread synchronization using spinlocks.

## Features

- **Reverse Polish Notation**: Stack-based expression evaluation
- **Hexadecimal arithmetic**: Operations on 64-bit numbers in base-16
- **Concurrent execution**: Multiple calculator instances running in parallel
- **Thread synchronization**: Custom spinlock implementation for the `W` operation
- **Hardware stack**: Direct use of CPU stack for calculations

## Operations

### Number Input
- `0-9, A-F, a-f`: Hex digits (automatic number accumulation mode)
- `=`: Exit number input mode

### Arithmetic Operations
- `+`: Addition
- `*`: Multiplication
- `-`: Negation (unary)

### Bitwise Operations
- `&`: AND
- `|`: OR
- `^`: XOR
- `~`: NOT (bitwise negation)

### Stack Manipulation
- `Y`: Duplicate top value
- `X`: Swap top two values
- `Z`: Remove top value

### Special Operations
- `N`: Push total number of Noteć instances
- `n`: Push current instance number
- `g`: Call external debug function
- `W`: Thread synchronization - exchange values between two Noteć instances

## API

```c
uint64_t notec(uint32_t n, char const *calc);
```

- `n`: Instance number (0 to N-1)
- `calc`: ASCIIZ string containing calculation
- Returns: Value from top of stack after execution

## Building

```bash
# Assemble
nasm -DN=$N -f elf64 -w+all -w+error -o notec.o notec.asm

# Compile example
gcc -DN=$N -c -Wall -Wextra -O2 -std=c11 -o example.o example.c

# Link
gcc notec.o example.o -lpthread -o example
```

Where `$N` is the number of concurrent Noteć instances.

## Example

```c
// Calculate: (~((0xab - 0x12) * 3) & 0xfff) | 0xcde09
notec(0, "6N8ZXab=12-+3*~FFF&cDe09|g");

// Exchange values between instances using thread synchronization
notec(0, "nY1^W");  // XOR instance number with 1, exchange with that instance
```

## Technical Details

- Pure x86_64 assembly implementation
- No external libraries
- ABI-compliant register and stack usage
- Spinlock-based synchronization without bus locking
- All arithmetic modulo 2^64

---

*Created in 2021 for the Operating Systems course at the University of Warsaw.*
