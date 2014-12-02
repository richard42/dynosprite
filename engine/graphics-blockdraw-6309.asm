*********************************************************************************
* DynoSprite - graphics-blockdraw-6309.asm
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

Draw1Row                                        * (56)
            ldq         ,x                      * 8
            stq         ,y                      * 8
            stq         $3FFF,y                 * 11
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         $4003,y                 * 11
            rts

Draw2Rows                                       * 121 (60.5/row)
            leau        $3fff,y                 * 7
*
            ldq         ,x                      * 8         row 0 (51)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 1 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            rts

Draw3Rows                                       * 184 (61.3/row)
            leau        $3fff,y                 * 7
*
            ldq         ,x                      * 8         row 0 (51)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 1 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 2 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         16,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         20,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            rts

Draw4Rows                                       * 247  (61.8/row)
            leau        $3fff,y                 * 7
*
            ldq         ,x                      * 8         row 0 (51)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 1 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 2 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         16,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         20,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 3 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         24,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         28,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            rts

Draw5Rows                                       * 310 (62/row)
            leau        $3fff,y                 * 7
*
            ldq         ,x                      * 8         row 0 (51)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 1 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 2 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         16,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         20,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 3 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         24,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         28,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 4 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         32,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         36,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            rts

Draw6Rows                                       * 373 (62.2/row)
            leau        $3fff,y                 * 7
*
            ldq         ,x                      * 8         row 0 (51)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 1 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 2 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         16,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         20,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 3 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         24,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         28,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 4 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         32,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         36,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 5 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         40,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         44,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            rts

Draw7Rows                                       * 436 (62.3/row)
            leau        $3fff,y                 * 7
*
            ldq         ,x                      * 8         row 0 (51)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 1 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 2 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         16,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         20,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 3 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         24,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         28,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 4 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         32,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         36,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 5 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         40,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         44,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 6 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         48,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         52,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            rts

Draw8Rows                                       * 499 (62.4/row)
            leau        $3fff,y                 * 7
*
            ldq         ,x                      * 8         row 0 (51)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 1 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 2 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         16,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         20,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 3 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         24,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         28,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 4 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         32,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         36,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 5 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         40,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         44,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 6 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         48,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         52,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 7 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         56,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         60,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            rts


Draw4PlusRows_Local
            lsra
Draw4PlusRows
            sta         lda_RowCounter@+1
            leau        $3fff,y                 * 7
*
Draw4Loop@
*
            ldq         ,x                      * 8         row 0 (51)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 1 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 2 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         16,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         20,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 3 (79)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         24,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         28,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            ldd         #256                    * 3
            addr        d,y                     * 4
            addr        d,u                     * 4
            leax        32,x                    * 5
lda_RowCounter@
            lda         #0                      * SMC: row counter is stored here
            suba        #4
            sta         lda_RowCounter@+1
            bita        #$FC
            bne         Draw4Loop@
            tst         lda_RowCounter@+1
            beq         Draw4PlusExit@
            ldq         ,x                      * 8         row 0 (60)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            dec         lda_RowCounter@+1       * 6
            beq         Draw4PlusExit@          * 3
*
            ldd         #256                    * 3         row 1 (72)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            dec         lda_RowCounter@+1
            beq         Draw4PlusExit@
*
            ldd         #256                    * 3         row 2 (72)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         16,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         20,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            dec         lda_RowCounter@+1
            beq         Draw4PlusExit@
*
            ldd         #256                    * 3         row 3 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         24,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         28,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
Draw4PlusExit@
            rts


Draw16Rows                                      * 1003 (62.7/row)
            leau        $3fff,y                 * 7
*
            ldq         ,x                      * 8         row 0 (51)
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         4,x                     * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 1 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         8,x                     * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         12,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 2 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         16,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         20,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 3 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         24,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         28,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 4 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         32,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         36,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 5 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         40,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         44,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 6 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         48,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         52,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 7 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         56,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         60,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 8 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         64,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         68,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 9 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         72,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         76,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 10 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         80,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         84,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 11 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         88,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         92,x                    * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 12 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         96,x                    * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         100,x                   * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 13 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         104,x                   * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         108,x                   * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 14 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         112,x                   * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         116,x                   * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
*
            ldd         #256                    * 3         row 15 (63)
            addr        d,y                     * 4
            addr        d,u                     * 4
            ldq         120,x                   * 9
            stq         ,y                      * 8
            stq         ,u                      * 8
            ldq         124,x                   * 9
            stq         4,y                     * 9
            stq         4,u                     * 9
            rts

