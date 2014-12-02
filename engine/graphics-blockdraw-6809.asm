*********************************************************************************
* DynoSprite - graphics-blockdraw-6809.asm
* Copyright (c) 2013-2014, Richard Goedeken
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
* Gfx_DrawBlockRows:
*   Note that the algorithm used for moving data in these block drawing routines
*   uses the CC register to store pixel values.  Due to the way that interrupts are
*   handled on the 6809 with the E bit, this can cause pixel data corruption in the
*   very left-most pixel of a 16x16 background image block.  In order to avoid this
*   corruption, the following pixel values should NOT be used in the left-most
*   column of any 16x16 background pixel block: for FIRQ interrupts (as used by
*   current DynoSprite engine, and required for audio performance), the left-most
*   row should not contain pixels with values of 8, 9, 10, or 11.  If IRQ-type
*   interrupts were used instead, then the values of: 0, 2, 4, or 6 should be avoided.
*
* - IN:      A = Rows to draw, X = pointer to 128 bytes of texture data for block
* - OUT:     Y = pointer to destination image data (256-byte rows)
* - Trashed: A,B,X,Y,U,DP
***********************************************************
*
DBR_Funcs@      fdb     Draw1Row
                fdb     Draw2Rows
                fdb     Draw3Rows
                fdb     Draw4Rows
                fdb     Draw5Rows
                fdb     Draw6Rows
                fdb     Draw7Rows
                fdb     Draw8Rows
                fdb     Draw4PlusRows_Local
                fdb     Draw4PlusRows_Local
                fdb     Draw4PlusRows_Local
                fdb     Draw4PlusRows_Local
                fdb     Draw4PlusRows_Local
                fdb     Draw4PlusRows_Local
                fdb     Draw4PlusRows_Local
                fdb     Draw16Rows
*
Gfx_DrawBlockRows
            ldu         #DBR_Funcs@-2           * 3
            lsla                                * 2
            jmp         [a,u]                   * 7

Draw1Row                                        * 77
            leau        $3FFF,y                 * 8
            ldd         ,x                      * 5
            std         ,y                      * 5
            std         ,u                      * 5
            ldd         2,x                     * 6
            std         2,y                     * 6
            std         2,u                     * 6
            ldd         4,x                     * 6
            std         4,y                     * 6
            std         4,u                     * 6
            ldd         6,x                     * 6
            std         6,y                     * 6
            std         6,u                     * 6
            rts

Draw2Rows                                       * 154 (77.0/row)
            pshs        x,y                     * 9       X (pSrc) is at top of stack
*
            leau        ,x                      * 4         row 0 (64)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            andcc       #$af                    * 3          make sure interrupts are enabled
            leas        4,s                     * 5
            rts

Draw3Rows                                       * 227 (75.6/row)
            pshs        x,y                     * 9       X (pSrc) is at top of stack
*
            leau        ,x                      * 4         row 0 (64)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 2 (73)
            leau        16,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $208,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            andcc       #$af                    * 3          make sure interrupts are enabled
            leas        4,s                     * 5
            rts

Draw4Rows                                       * 300  (75.0/row)
            pshs        x,y                     * 9       X (pSrc) is at top of stack
*
            leau        ,x                      * 4         row 0 (64)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 2 (73)
            leau        16,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $208,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 3 (73)
            leau        24,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $308,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            andcc       #$af                    * 3          make sure interrupts are enabled
            leas        4,s                     * 5
            rts

Draw5Rows                                       * 373 (74.6/row)
            pshs        x,y                     * 9       X (pSrc) is at top of stack
*
            leau        ,x                      * 4         row 0 (64)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 2 (73)
            leau        16,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $208,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 3 (73)
            leau        24,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $308,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 4 (73)
            leau        32,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $408,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            andcc       #$af                    * 3          make sure interrupts are enabled
            leas        4,s                     * 5
            rts





Draw6Rows                                       * 446 (74.333/row)
            pshs        x,y                     * 9       X (pSrc) is at top of stack
*
            leau        ,x                      * 4         row 0 (64)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 2 (73)
            leau        16,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $208,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 3 (73)
            leau        24,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $308,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 4 (73)
            leau        32,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $408,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 5 (73)
            leau        40,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $508,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            andcc       #$af                    * 3          make sure interrupts are enabled
            leas        4,s                     * 5
            rts

Draw7Rows                                       * 519 (74.14/row)
            pshs        x,y                     * 9       X (pSrc) is at top of stack
*
            leau        ,x                      * 4         row 0 (64)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 2 (73)
            leau        16,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $208,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 3 (73)
            leau        24,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $308,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 4 (73)
            leau        32,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $408,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 5 (73)
            leau        40,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $508,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13

*
            ldu         ,s                      * 5         row 6 (73)
            leau        48,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $608,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            andcc       #$af                    * 3          make sure interrupts are enabled
            leas        4,s                     * 5
            rts

Draw8Rows                                       * 592 (74.0/row)
            pshs        x,y                     * 9       X (pSrc) is at top of stack
*
            leau        ,x                      * 4         row 0 (64)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 2 (73)
            leau        16,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $208,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 3 (73)
            leau        24,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $308,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 4 (73)
            leau        32,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $408,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 5 (73)
            leau        40,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $508,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13

*
            ldu         ,s                      * 5         row 6 (73)
            leau        48,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $608,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13

*
            ldu         ,s                      * 5         row 7 (73)
            leau        56,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $708,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            andcc       #$af                    * 3          make sure interrupts are enabled
            leas        4,s                     * 5
            rts

Draw4PlusRows_Local
            lsra
Draw4PlusRows
            sta         lda_RowCounter@+1
            pshs        x,y                     * 9       X (pSrc) is at top of stack
*
Draw4Loop@
            ldu         ,s                      * 5         row 0 (65)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 2 (73)
            leau        16,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $208,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            puls        u                       * 7         row 3 (82)
            leau        24,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            pshs        u                       * 7
            leau        [2,s]                   * 8
            leau        $308,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            leau        -$3eff,u
            stu         2,s
lda_RowCounter@
            lda         #0                      * SMC: row counter is stored here
            suba        #4
            sta         lda_RowCounter@+1
            bita        #$FC
            bne         Draw4Loop@
            tst         lda_RowCounter@+1
            beq         Draw4PlusExit@
*
            ldu         ,s                      * 5         row 0 (65)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
            dec         lda_RowCounter@+1
            beq         Draw4PlusExit@
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
            dec         lda_RowCounter@+1
            beq         Draw4PlusExit@
*
            ldu         ,s                      * 5         row 2 (73)
            leau        16,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $208,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
Draw4PlusExit@
            andcc       #$af                    * 3          make sure interrupts are enabled
            leas        4,s                     * 5
            rts

Draw16Rows                                      * 1176 (73.5/row)
            pshs        x,y                     * 9       X (pSrc) is at top of stack
*
            leau        ,x                      * 4         row 0 (64)
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        8,u                     * 5
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 1 (73)
            leau        8,u                     * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $108,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 2 (73)
            leau        16,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $208,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 3 (73)
            leau        24,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $308,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 4 (73)
            leau        32,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $408,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 5 (73)
            leau        40,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $508,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 6 (73)
            leau        48,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $608,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 7 (73)
            leau        56,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $708,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 8 (73)
            leau        64,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $808,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 9 (73)
            leau        72,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $908,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 10 (73)
            leau        80,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $a08,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 11 (73)
            leau        88,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $b08,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 12 (73)
            leau        96,u                    * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $c08,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 13 (73)
            leau        104,u                   * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $d08,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 14 (73)
            leau        112,u                   * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $e08,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            ldu         ,s                      * 5         row 15 (73)
            leau        120,u                   * 5
            pulu        cc,a,b,dp,x,y           * 13
            leau        [2,s]                   * 8
            leau        $f08,u                  * 8
            pshu        cc,a,b,dp,x,y           * 13
            leau        $3fff+8,u               * 8
            pshu        cc,a,b,dp,x,y           * 13
*
            andcc       #$af                    * 3          make sure interrupts are enabled
            leas        4,s                     * 5
            rts


