*********************************************************************************
* DynoSprite - math.asm
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
* Math_Divide16by8:
*
* This routine divides a 16-bit unsigned integer by an 8-bit unsigned integer,
* producing a 16-bit quotient and 8-bit remainder. The algorithm was taken from:
*     http://www.programmersheaven.com/mb/pharabee/175172/175172/motorola-6809--divison-routines-anyone/
*
* - IN:      Math_Dividend_16, Math_Divisor_8
* - OUT:     Math_Quotient_16, Math_Remainder_8
* - Trashed: A,B,X,Y
***********************************************************

Math_Dividend_16        rmd     1
Math_Divisor_8          rmb     1
Math_Quotient_16        rmd     1
Math_Remainder_8        rmb     1
*
* 16-bit by 8-bit division
* Timing = 18 + 16*(45) + 30 = 768 clock cycles
*
LoopCount@              rmb     1
*
Math_Divide16by8:
            ldx         #16                     * 3
            sta         LoopCount@              * 5
            ldy         #0                      * 4 (clear remainder)
            ldd         Math_Dividend_16        * 6 (working quotient)
DivLoop@
            rolb                                * 2
            eorb        #1                      * 2
            rola                                * 2
            exg         d,y                     * 8
            rola                                * 2
            suba        Math_Divisor_8          * 5
            bcc         DivLoop_NoBorrow@       * 3
            adda        Math_Divisor_8          * 5
DivLoop_NoBorrow@
            exg         d,y                     * 8
            leax        -1,x                    * 5
            bne         DivLoop@                * 3
            rolb                                * 2
            eorb        #1                      * 2
            rola                                * 2
            std         Math_Quotient_16        * 6
            exg         d,y                     * 8
            sta         Math_Remainder_8        * 5
            rts                                 * 5

***********************************************************
* Math_Divide16by16:
*
* This routine divides a 16-bit unsigned integer by an 16-bit unsigned integer,
* producing a 16-bit quotient and 16-bit remainder.
*
* - IN:      Math_Dividend_16, Math_Divisor_16
* - OUT:     Math_Quotient_16, Math_Remainder_16
* - Trashed: A,B,X,Y
***********************************************************

Math_Divisor_16         rmd     1
Math_Remainder_16       rmd     1
*
* 16-bit by 16-bit division
* Timing = 18 + 16*(51) + 31 = 865 clock cycles
*
LoopCount@              rmb     1
*
Math_Divide16by16:
            ldx         #16                     * 3
            sta         LoopCount@              * 5
            ldy         #0                      * 4 (clear remainder)
            ldd         Math_Dividend_16        * 6 (working quotient)
DivLoop@
            rolb                                * 2
            eorb        #1                      * 2
            rola                                * 2
            exg         d,y                     * 8
            rolb                                * 2
            rola                                * 2
            subd        Math_Divisor_16         * 7
            bcc         DivLoop_NoBorrow@       * 3
            addd        Math_Divisor_16         * 7
DivLoop_NoBorrow@
            exg         d,y                     * 8
            leax        -1,x                    * 5
            bne         DivLoop@                * 3
            rolb                                * 2
            eorb        #1                      * 2
            rola                                * 2
            std         Math_Quotient_16        * 6
            exg         d,y                     * 8
            std         Math_Remainder_16       * 6
            rts                                 * 5

***********************************************************
* Math_Multiply16by16:
*
* - IN:      Math_Multiplicand_16, Math_Multiplier_16
* - OUT:     Math_Product_32
* - Trashed: A,B
***********************************************************

Math_Multiplicand_16    rmd     1
Math_Multiplier_16      rmd     1
Math_Product_32         rmd     2
*
Math_Multiply16by16:
            clra
            clrb
            std         Math_Product_32
            std         Math_Product_32+2
            lda         Math_Multiplicand_16+1
            ldb         Math_Multiplier_16+1
            mul
            std         Math_Product_32+2
            lda         Math_Multiplicand_16
            ldb         Math_Multiplier_16+1
            mul
            addd        Math_Product_32+1
            std         Math_Product_32+1
            bcc         >
            inc         Math_Product_32
!           lda         Math_Multiplicand_16+1
            ldb         Math_Multiplier_16
            mul
            addd        Math_Product_32+1
            std         Math_Product_32+1
            bcc         >
            inc         Math_Product_32
!           lda         Math_Multiplicand_16
            ldb         Math_Multiplier_16
            mul
            addd        Math_Product_32
            std         Math_Product_32
            rts

