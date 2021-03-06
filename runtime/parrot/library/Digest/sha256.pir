# Copyright (C) 2010, Parrot Foundation.
#
# Parrot SHA-2 library; Gerd Pokorra <gp@zimt.uni-siegen.de>
#
# Based on sha256.c, from sha256sum
#           written by David Madore
#
# Functions that are from the SHA-2 family to compute SHA-224 and SHA-256
# message digest according to the NIST specification FIPS 180-3:
# http://csrc.nist.gov/publications/fips/fips180-3/fips180-3_final.pdf
#
# NIST = National Institute of Standards and Technology
# FIPS = Federal Information Processing Standards

# This is the start of the implemation and sha224 is not done yet!

=head1 NAME

sha256.pir - calculates message digest checksums

=head1 SYNOPSIS

  load_bytecode "Digest/sha256.pbc"
  $P0 = sha256sum("foo")
  sha256_print($P0)

or

  load_bytecode "Digest/sha256.pbc"
  $P0 = sha256sum("bar")
  $S0 = sha256_hex($P0)

=head1 DESCRIPTION

This is a pure Parrot sha256 hash routine. You should run it with the JIT
core if possible.

=head1 SUBROUTINES

=head2 sha256sum

Pass in a string, returns an Integer array with the result.

=head2 sha256_hex

Pass it the Integer array from sha256sum to get the checksum as string.

=head2 sha256_print

Pass it the Integer array to print the checksum.

=head1 BUGS

Still has some limitations on input buffer size, largely due to memory
consumption which should be resolved soon.

=cut


.HLL 'parrot'

#.loadlib 'bit_ops'

###########################################################################

# Export function entries to globals

.sub onload :load

    .local pmc f
    f = get_hll_global ['Digest'], '_sha256sum'
    set_global "sha256sum", f
    f = get_hll_global ['Digest'], '_sha256_hex'
    set_global "sha256_hex", f
    f = get_hll_global ['Digest'], '_sha256_print'
    set_global "sha256_print", f
.end

###########################################################################

# Main backend entry point

.namespace ["Digest"]

.sub _sha256sum
    .param string str

    .local pmc context
    context = new 'FixedIntegerArray'
    context = 8

    .local pmc buffer
    buffer = _sha256_create_buffer (str)

    _sha256_init (context)
    _sha256_process_buffer (context, buffer)

    .return (context)
.end


###########################################################################

# Create an internal scratchpad buffer

.sub _sha256_create_buffer
    .param string str

    .local pmc buffer
    buffer = new 'FixedIntegerArray'

    .local int counter
    .local int subcounter
    .local int slow_counter

    .local int word, len

     len = length str

     $I1 = len - 1

     # Work out how many words to allocate
     .local int words
     words  = len + 8
     words |= 63
     inc words
     words /= 4

     buffer = words

     word         = 0
     counter      = 0
     subcounter   = 0
     slow_counter = 0

create_buffer_loop:

     $I5 = counter + subcounter

     if $I5 > len goto create_buffer_break

     # pad character, which goes last (append the bit "1" to the end of the
     #                                 message)
     $I4 = 0x80

     if $I5 > $I1 goto string_char
     $I4 = ord str, $I5

string_char:

     word <<= 8
     word  |= $I4

     inc subcounter
     if subcounter != 4 goto create_buffer_loop

     word = _byte_order (word)

     buffer[slow_counter] = word

     word       = 0
     counter   += 4
     subcounter = 0
     inc slow_counter

     goto create_buffer_loop

create_buffer_break:

     # Check for a partial word

     if subcounter == 0 goto complete
     subcounter = 4 - subcounter
     $I0    = 8*subcounter
     word <<= $I0

     word = _byte_order (word)

     buffer[slow_counter] = word

complete:

     # The length of the string go into the last two words (64 bits)

     $I0 = len << 3
     dec words
     $I0 = _byte_order ($I0)
     buffer[words] = $I0

     $I0 = len >>> 29
     dec words
     buffer[words] = $I0

     .return (buffer)
.end

###########################################################################

# Pass in the Interger array and return the final checksum as a string

.sub _sha256_hex
    .param pmc context

    $S0 = sprintf "%08lx%08lx%08lx%08lx%08lx%08lx%08lx%08lx", context

    .return ($S0)
.end

###########################################################################

# Convenience subroutine to print the Message Digest
# - Pass in the Integer array
# - Retrieve the final checksum as a string
# - Print the Message Digest

.sub _sha256_print
    .param pmc context

    $S0 = _sha256_hex (context)
    print $S0

    .return ($S0)
.end

###########################################################################

# Set the start constants of the SHA256 algorithm

.sub _sha256_init
    .param pmc context

    # Initial constants
    context[0] = 0x6a09e667
    context[1] = 0xbb67ae85
    context[2] = 0x3c6ef372
    context[3] = 0xa54ff53a
    context[4] = 0x510e527f
    context[5] = 0x9b05688c
    context[6] = 0x1f83d9ab
    context[7] = 0x5be0cd19

.end

###########################################################################

.sub _Ch
    .param pmc context

    .local int E, F, G, result

    E = context[4]
    F = context[5]
    G = context[6]

    # Ch(x,y,z) = ( x and y ) xor ( not(x) and z ) = z xor ( x and ( y xor z )
    # here as:    Ch(E,F,G)                        = G xor ( E and ( F xor G )
    result = bxor F, G
    result = band E, result
    result = bxor G, result

    .return (result)
.end

###########################################################################

.sub _Maj
    .param pmc context

    .local int A, B, C, extension, result

    A = context[0]
    B = context[1]
    C = context[2]

    # Maj(x,y,z) = ( x and y ) xor ( x and z ) xor ( y and z )
    #            = ( x and y ) or ( z and ( x or y ) )
    # here as: Maj(A,B,C) = ( A and B ) or ( C and ( A or B ) )
    result = bor A, B
    result = band C, result
    extension = band A, B
    result = bor extension, result

    .return (result)
.end

###########################################################################

.sub _rotate_right
    # circular right shift operation, where x is a 32-bit word and n is an
    # integer
    .param int x
    .param int n

    .local int extension, result
    extension = shr x, n

    result = 32 - n
    result = shl x, result
    # For 64-bit architectures, to remove leading 32-bit
    result = band result, 0xffffffff

    result = bor extension, result

    .return (result)
.end

###########################################################################

.sub _Sigma_0
    .param pmc context

    .local int A, intermediate, result

    A = context[0]

    intermediate = _rotate_right( A, 2 )
    result = _rotate_right( A, 13 )
    result = bxor intermediate, result

    intermediate = _rotate_right( A, 22 )
    result = bxor intermediate, result

    .return (result)
.end

###########################################################################

.sub _Sigma_1
    .param pmc context

    .local int E, intermediate, result

    E = context[4]

    intermediate = _rotate_right( E, 6 )
    result = _rotate_right( E, 11 )
    result = bxor intermediate, result

    intermediate = _rotate_right( E, 25 )
    result = bxor intermediate, result

    .return (result)
.end

###########################################################################

.sub _sigma0
    .param int value

    .local int intermediate, result

    intermediate = _rotate_right( value, 7 )
    result = _rotate_right( value, 18 )
    result = bxor intermediate, result

    intermediate = shr value, 3
    result = bxor intermediate, result

    .return (result)
.end

###########################################################################

.sub _sigma1
    .param int value

    .local int intermediate, result

    intermediate = _rotate_right( value, 17 )
    result = _rotate_right( value, 19 )
    result = bxor intermediate, result

    intermediate = shr value, 10
    result = bxor intermediate, result

    .return (result)
.end

###########################################################################

.sub _byte_order
    # If the byte oder (byte sex) is big-endian, then nothing is to do
    # here, that is not implemented and has to been fixed
    .param int w
    .local int part1, part2, part3, part4

    part1 = w & 0x000000ff
    part2 = w & 0x0000ff00
    part3 = w & 0x00ff0000
    part4 = w & 0xff000000

    part1 = part1 <<  24
    part2 = part2 <<  8
    part3 = part3 >>> 8
    part4 = part4 >>> 24

    part1 |= part2
    part1 |= part3
    part1 |= part4

    # For 64-bit architectures
    part1 = part1 & 0xffffffff

    .return (part1)
.end

###########################################################################

.sub _W_from_t
    .param pmc message
    .param int m_index

    .local int tmp, result

    tmp = m_index - 2
    tmp = band tmp, 0x0f
    tmp = message[tmp]
    tmp = _sigma1 (tmp)

    result = m_index - 7
    result = band result, 0x0f
    result = message[result]

    result += tmp

    tmp = m_index - 15
    tmp = band tmp, 0x0f
    tmp = message[tmp]
    tmp = _sigma0 (tmp)

    result += tmp

    tmp = band m_index, 0x0f
    tmp = message[tmp]

    result += tmp
    result = band result, 0xffffffff

    tmp = band m_index, 0x0f
    message[tmp] = result

    .return (result)
.end

###########################################################################

.sub _sha256_process_block
    .param pmc context
    .param pmc buffer

    .local int a_save, b_save, c_save, d_save, e_save, f_save, g_save, h_save
    a_save = context[0]
    b_save = context[1]
    c_save = context[2]
    d_save = context[3]
    e_save = context[4]
    f_save = context[5]
    g_save = context[6]
    h_save = context[7]

    # 64 round constants as 32-bit words
    .local pmc K
    K = new 'FixedIntegerArray'
    K = 64
    K[0]  = 0x428a2f98
    K[1]  = 0x71374491
    K[2]  = 0xb5c0fbcf
    K[3]  = 0xe9b5dba5
    K[4]  = 0x3956c25b
    K[5]  = 0x59f111f1
    K[6]  = 0x923f82a4
    K[7]  = 0xab1c5ed5
    K[8]  = 0xd807aa98
    K[9]  = 0x12835b01
    K[10] = 0x243185be
    K[11] = 0x550c7dc3
    K[12] = 0x72be5d74
    K[13] = 0x80deb1fe
    K[14] = 0x9bdc06a7
    K[15] = 0xc19bf174
    K[16] = 0xe49b69c1
    K[17] = 0xefbe4786
    K[18] = 0x0fc19dc6
    K[19] = 0x240ca1cc
    K[20] = 0x2de92c6f
    K[21] = 0x4a7484aa
    K[22] = 0x5cb0a9dc
    K[23] = 0x76f988da
    K[24] = 0x983e5152
    K[25] = 0xa831c66d
    K[26] = 0xb00327c8
    K[27] = 0xbf597fc7
    K[28] = 0xc6e00bf3
    K[29] = 0xd5a79147
    K[30] = 0x06ca6351
    K[31] = 0x14292967
    K[32] = 0x27b70a85
    K[33] = 0x2e1b2138
    K[34] = 0x4d2c6dfc
    K[35] = 0x53380d13
    K[36] = 0x650a7354
    K[37] = 0x766a0abb
    K[38] = 0x81c2c92e
    K[39] = 0x92722c85
    K[40] = 0xa2bfe8a1
    K[41] = 0xa81a664b
    K[42] = 0xc24b8b70
    K[43] = 0xc76c51a3
    K[44] = 0xd192e819
    K[45] = 0xd6990624
    K[46] = 0xf40e3585
    K[47] = 0x106aa070
    K[48] = 0x19a4c116
    K[49] = 0x1e376c08
    K[50] = 0x2748774c
    K[51] = 0x34b0bcb5
    K[52] = 0x391c0cb3
    K[53] = 0x4ed8aa4a
    K[54] = 0x5b9cca4f
    K[55] = 0x682e6ff3
    K[56] = 0x748f82ee
    K[57] = 0x78a5636f
    K[58] = 0x84c87814
    K[59] = 0x8cc70208
    K[60] = 0x90befffa
    K[61] = 0xa4506ceb
    K[62] = 0xbef9a3f7
    K[63] = 0xc67178f2

    .local int Ki, T1, T2, tmp
    .local pmc M_t
    M_t = new 'FixedIntegerArray'
    M_t = 16
    .local int counter
    counter = 0

LOOP:   if counter > 63 goto DONE
    # part 1 from the calculation of T1
    tmp = _Sigma_1 (context)
    T1 = context[7]
    T1 += tmp
    tmp = _Ch (context)
    T1 += tmp
    Ki = K [counter]
    T1 = T1 + Ki
    T1 = band T1, 0xffffffff

    # calculataion of T2
    T2 = _Sigma_0 (context)
    tmp = _Maj (context)
    T2 += tmp
    T2 = band T2, 0xffffffff

    if counter < 16 goto NIL_TO_15

    # calculation of W(t) from 16 to 63
    tmp = _W_from_t (M_t, counter)
    T1 += tmp

    goto COMMON_CHANGE_PART

NIL_TO_15:
    # part 2 from the calculation of T1
    # change the byte-order
    tmp = buffer[counter]
    tmp = _byte_order(tmp)

    # add to the message block
    M_t[counter] = tmp

    T1 = T1 + tmp       # that is T1
    T1 = band T1, 0xffffffff

COMMON_CHANGE_PART:
    # set context for next round
    tmp = context[6]
    context[7] = tmp            # h=g
    tmp = context[5]
    context[6] = tmp            # g=f
    tmp = context[4]
    context[5] = tmp            # f=e
    tmp = context[3]
    tmp += T1
    tmp = tmp & 0xffffffff
    context[4] = tmp            # e=d+T1
    tmp = context[2]
    context[3] = tmp            # d=c
    tmp = context[1]
    context[2] = tmp            # c=b
    tmp = context[0]
    context[1] = tmp            # b=a
    tmp = T1 + T2
    tmp = tmp & 0xffffffff
    context[0] = tmp            # a=T1+T2

    inc counter
    goto LOOP

DONE:
    tmp = context[0]
    a_save += tmp
    a_save = a_save & 0xffffffff
    context[0] = a_save
    tmp = context[1]
    b_save += tmp
    b_save = b_save & 0xffffffff
    context[1] = b_save
    tmp = context[2]
    c_save += tmp
    c_save = c_save & 0xffffffff
    context[2] = c_save
    tmp = context[3]
    d_save += tmp
    d_save = d_save & 0xffffffff
    context[3] = d_save
    tmp = context[4]
    e_save += tmp
    e_save = e_save & 0xffffffff
    context[4] = e_save
    tmp = context[5]
    f_save += tmp
    f_save = f_save & 0xffffffff
    context[5] = f_save
    tmp = context[6]
    g_save += tmp
    g_save = g_save & 0xffffffff
    context[6] = g_save
    tmp = context[7]
    h_save += tmp
    h_save = h_save & 0xffffffff
    context[7] = h_save
.end

###########################################################################

.sub _sha256_process_buffer
    .param pmc context
    .param pmc buffer

    .local int idx, i2, len, tmp
    .local pmc part

    part = new 'FixedIntegerArray'
    part = 16

    idx = 0
    i2 = 0
    len = elements buffer

BLOCK_LOOP:
    tmp = idx + i2
    tmp = buffer[tmp]
    part[i2] = tmp
    inc i2
    if i2 < 16 goto BLOCK_LOOP

    _sha256_process_block (context, part)

    idx += 16
    i2 = 0
    if idx < len goto BLOCK_LOOP

.end

## Functions that could be used for debugging
###########################################################################

.sub _print_integer_in_hex_format
    .param int hex_num
    $P0 = new 'FixedIntegerArray'
    $P0 = 1
    $P0[0] = hex_num
    $S0 = sprintf "%08lx", $P0

    print 'value in hex-format: '
    say $S0
    #say ''
.end

###########################################################################

.sub _print_round
    .param pmc context

    $S0 = sprintf "%08X %08X %08X %08X %08X %08X %08X %08X", context
    say $S0
.end

###########################################################################

.sub _print_message
    .param pmc buffer

    .local int idx, i2, len, tmp
    .local pmc part

    part = new 'FixedIntegerArray'
    part = 16

    idx = 0
    i2 = 0
    len = elements buffer

AGAIN:
    tmp = idx + i2
    tmp = buffer[tmp]
    part[i2] = tmp
    inc i2
    if i2 < 16 goto AGAIN
    sprintf $S0, " 0: %08x\n 1: %08x\n 2: %08x\n 3: %08x\n 4: %08x\n 5: %08x\n 6: %08x\n 7: %08x\n 8: %08x\n 9: %08x\n10: %08x\n11: %08x\n12: %08x\n13: %08x\n14: %08x\n15: %08x\n", part
    say $S0

    idx += 16
    i2 = 0
    if idx < len goto AGAIN
.end

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
