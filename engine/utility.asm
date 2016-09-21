*********************************************************************************
* DynoSprite - utility.asm
* Copyright (c) 2013, Richard Goedeken
* All rights reserved.
* 
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
* 
* * Redistributions of source code must retain the above copyright notice, this
*   list of conditions and the following disclaimer.
* 
* * Redistributions in binary form must reproduce the above copyright notice,
*   this list of conditions and the following disclaimer in the documentation
*   and/or other materials provided with the distribution.
* 
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*********************************************************************************


***********************************************************
* Util_StrLen:
* - IN:      X=pointer to NULL-terminated string
* - OUT:     A=string length
* - Trashed: None
***********************************************************
Util_StrLen
            clra
StrLoop@
            tst         a,x
            beq         >
            inca
            bra         StrLoop@
!           rts

***********************************************************
* Util_Random:
* - IN:      
* - OUT:     A=psuedo-random number
* - Trashed: A
***********************************************************
VarX@           fcb     18
VarA@           fcb     166
VarB@           fcb     220
VarC@           fcb     64
*
Util_Random
            inc         VarX@
            lda         VarA@
            eora        VarC@
            eora        VarX@
            sta         VarA@
            adda        VarB@
            sta         VarB@
            lsra             
            eora        VarA@
            adda        VarC@
            sta         VarC@
            rts


***********************************************************
* Util_RandomRange16:
* - IN:      D=maximum value
* - OUT:     D=psuedo-random number between 0 and Din
* - Trashed: None
***********************************************************
*
Util_RandomRange16
            std         Math_Multiplier_16
            bsr         Util_Random
            sta         Math_Multiplicand_16
            bsr         Util_Random
            sta         Math_Multiplicand_16+1
            jsr         Math_Multiply16by16
            ldd         Math_Product_32
            rts


***********************************************************
* Util_ByteToAsciiHex:
* - IN:      A = word to write
*            X = left-most byte of text string to fill
* - OUT:     
* - Trashed: A,B,U
***********************************************************
*
HexDigits@              fcc     '0123456789ABCDEF'
*
Util_ByteToAsciiHex:
            ldu         #HexDigits@
            tfr         a,b
            lsrb
            lsrb
            lsrb
            lsrb
            ldb         b,u
            stb         ,x
            anda        #$0f
            lda         a,u
            sta         1,x
            rts
***********************************************************
* Util_WordToAsciiHex:
* - IN:      D = word to write
*            X = left-most byte of text string to fill
* - OUT:     
* - Trashed: A,B,U
***********************************************************
*
Util_WordToAsciiHex:
            ldu         #HexDigits@
            pshs        b
            tfr         a,b
            lsrb
            lsrb
            lsrb
            lsrb
            ldb         b,u
            stb         ,x
            anda        #$0f
            lda         a,u
            sta         1,x
            puls        a
            tfr         a,b
            lsrb
            lsrb
            lsrb
            lsrb
            ldb         b,u
            stb         2,x
            anda        #$0f
            lda         a,u
            sta         3,x
            rts

