*********************************************************************************
* DynoSprite - game/objects/01-numerals.asm
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
* Note: Object handling assembly code must be position-independent, because it can
*       be loaded in different locations depending on the level.
*       1. If you use local variables, you must address them with PC-relative modes
*       2. You can only call locally defined functions with B**/LB** instuctions (no JSR or JMP)
*       This only applies for local data and code.  You can reference functions or data which are
*       defined in the DynoSprite core with position-dependent instructions, because the addresses
*       for these items are known at assembly time.

* -----------------------------------------------------------------------------
* -- Type definitions only
* -----------------------------------------------------------------------------

            include     macros.asm
            include     datastruct.asm
            include     dynosprite-symbols.asm

* -----------------------------------------------------------------------------
* -- Object 0 -- 6-digit BCD Counter
* -----------------------------------------------------------------------------

* Object Initialization Function:
* - IN:      X = pointer to Current Object Table for this object instance
*            Y = pointer to Object Descriptor Table for this object type
*            U = pointer to initialization data in object init stream
* - OUT:     none
* - Trashed: all
*
Demo_Object0_Init
            * copy 3 bytes (BCD counter starting value) from init stream to object state
            ldx         COB.statePtr,x
            lda         ,u
            sta         ,x
            ldd         1,u
            std         1,x
            rts

Demo_Object0_Reactivate
            rts

* Object Update Function:
* - IN:      X = pointer to Current Object Table for this object instance
*            U = pointer to Object Descriptor Table for this object type
* - OUT:     none
* - Trashed: all
*
Demo_Object0_Update
            lda         <Obj_MotionFactor       * get # of fields to advance the counter value
            adda        #2
            ldx         COB.statePtr,x
            adda        2,x
            daa
            sta         2,x
            lda         1,x
            adca        #0
            daa
            sta         1,x
            lda         ,x
            adca        #0
            daa
            sta         ,x
            rts

* Object Custom Draw Function:
* - IN:      X = pointer to Current Object Table for this object instance
*            U = pointer to Object Descriptor Table for this object type
* - OUT:     none
* - Trashed: all
*
Demo_Object0_Draw
            * our globalX and globalY are actually screen-relative (local), and X is in bytes
            * start by calculating the page,offset pair where we will draw
            ldd         <Gfx_DrawScreenOffset   * must be between 0 and $1FFF
            adda        COB.globalY+1,x         * each line in Y is 256 bytes
            addb        COB.globalX+1,x
            adca        #0
            pshs        a
            anda        #$1F
            tfr         d,u                     * offset is in U
            leau        $8000,u                 * U is now pointer where we will write pixel data
            puls        a
            lsra
            lsra
            lsra
            lsra
            lsra
            adda        <Gfx_DrawScreenPage     * page is in A
            * corner case: if starting offset is really close to the beginning of a page, we need to map the prior page as well,
            * because the draw/erase functions may load/store the first byte with an offset of up to -2 from the X register
            cmpu        #$8004
            bhs         >
            leau        $2000,u
            deca
 IFDEF DEBUG
            bpl         >
            swi                                 * error: starting page is first page
 ENDC
!           sta         <DigitDrawSpritePage,PCR
            * screen window is mapped to $8000-$BFFF
            sta         $FFA4
            inca
            sta         $FFA5                   * screen window is mapped to $8000-$BFFF
            exg         x,u
            ldy         COB.sprPtr,u            * Y is pointer to Sprite Descriptor Table for group 0 (numerals)
            ldu         COB.statePtr,u
            lda         #101010b                * draw 6 digits (weird counter)
            ldb         ,u+                     * get first byte
            bra         DigitDraw
*
DigitDrawSpritePage     zmb  1
*
DigitDraw
            pshs        a,b,x,y,u
            clra
            andb        #$F0                    * B is first nibble value * 16
            leau        d,y                     * now U points to Sprite Descriptor Table entry to draw
            ldy         <Gfx_SpriteErasePtrPtr
            ldy         2,y
            ldd         SDT.erase,u
            std         ,y++                    * store pointer to erase function before the background pixels
            pshs        u,x
            lda         SDT.cpLeft,u            * map Sprite Code Page containing this DrawLeft to $4000
            ldb         #2
            jsr         MemMgr_MapBlock
            puls        x
            jsr         [SDT.drawLeft,u]        * draw this digit
            puls        u                       * restore pointer to Sprite Descriptor Table for sprite drawn
            ldx         <Gfx_SpriteErasePtrPtr
            ldy         2,x
            ldd         SDT.storeBytes,u
            ADD_D_TO_Y                          * Y is pointer to 2 bytes before end of newly written pixel restore data
            std         2,y                     * store (word) number of pixel restore bytes in this block
            lda         SDT.cpErase,u
            sta         4,y                     * store code page for erase function before the background pixels
            lda         <DigitDrawSpritePage,PCR
            sta         5,y                     * store page where pixel data were stored
            ldd         2,s                     * D is value of X before push (graphics memory pointer)
            subd        #$2000                  * graphics memory window starts from $6000 during sprite erase (our window starts at $8000)
            std         6,y
            clr         8,y
            leay        9,y                     * now Y is pointer to end of sprite erase heap
            sty         2,x
 IFDEF DEBUG
            tfr         y,d
            subd        ,x                      * D is now size of sprite erase heap for this frame
            cmpa        #$10
            blo         >
            swi                                 * error, heap overflow
 ENDC
!           puls        a,b,x,y,u
            lsra
            bne         >
            rts                                 * all done
!           bcs         LoadNewByte@
            lslb                                * move 2nd nibble of this byte into position
            lslb
            lslb
            lslb
            bra         DrawLoopTail@
LoadNewByte@
            ldb         ,u+
DrawLoopTail@
            leax        5,x                     * advance graphics memory pointer by 5 bytes (10 pixels)
            bra         DigitDraw


* -----------------------------------------------------------------------------
* -- Object 1 -- Hex Memory Value Readout
* -----------------------------------------------------------------------------

* Object Initialization Function:
* - IN:      X = pointer to Current Object Table for this object instance
*            Y = pointer to Object Descriptor Table for this object type
*            U = pointer to initialization data in object init stream
* - OUT:     none
* - Trashed: all
*
Demo_Object1_Init
            * copy 3 bytes (number of bytes, starting address) from init stream to object state
            ldx         COB.statePtr,x
            lda         ,u
            sta         ,x
            ldd         1,u
            std         1,x
            rts

Demo_Object1_Reactivate
            rts

* Object Update Function:
* - IN:      X = pointer to Current Object Table for this object instance
*            U = pointer to Object Descriptor Table for this object type
* - OUT:     none
* - Trashed: all
*
Demo_Object1_Update
            rts

* Object Custom Draw Function:
* - IN:      X = pointer to Current Object Table for this object instance
*            U = pointer to Object Descriptor Table for this object type
* - OUT:     none
* - Trashed: all
*
Demo_Object1_Draw
            * our globalX and globalY are actually screen-relative (local), and X is in bytes
            * start by calculating the page,offset pair where we will draw
            ldd         <Gfx_DrawScreenOffset   * must be between 0 and $1FFF
            adda        COB.globalY+1,x         * each line in Y is 256 bytes
            addb        COB.globalX+1,x
            adca        #0
            pshs        a
            anda        #$1F
            tfr         d,u                     * offset is in U
            leau        $8000,u                 * U is now pointer where we will write pixel data
            puls        a
            lsra
            lsra
            lsra
            lsra
            lsra
            adda        <Gfx_DrawScreenPage     * page is in A
            * corner case: if starting offset is really close to the beginning of a page, we need to map the prior page as well,
            * because the draw/erase functions may load/store the first byte with an offset of up to -2 from the X register
            cmpu        #$8004
            bhs         >
            leau        $2000,u
            deca
 IFDEF DEBUG
            bpl         >
            swi                                 * error: starting page is first page
 ENDC
!           sta         DigitDrawSpritePage,PCR
            * screen window is mapped to $8000-$BFFF
            sta         $FFA4
            inca
            sta         $FFA5                   * screen window is mapped to $8000-$BFFF
            exg         x,u
            ldy         COB.sprPtr,u            * Y is pointer to Sprite Descriptor Table for group 0 (numerals)
            ldu         COB.statePtr,u
            ldb         ,u+                     * B is number of bytes to display
 IFDEF DEBUG
            cmpb        #4
            bls         >
            swi                                 * error, we can only display 1-4 bytes
 ENDC
!           ldu         ,u                      * U now points to the data we want to display
            clra
!           ora         #10b                    * weird counter
            decb
            beq         >
            lsla
            lsla
            bra         <
!           ldb         ,u+                     * get first byte of data to display
            lbra        DigitDraw

* -----------------------------------------------------------------------------
* -- Data tables
* -----------------------------------------------------------------------------

NumberOfObjects         fcb     2
ObjectDescriptorTable
                        fcb     3               * dataSize
                        fcb     0               * drawType == 0: custom function
                        fcb     3               * initSize
                        fcb     0               * res1
                        fdb     Demo_Object0_Init
                        fdb     Demo_Object0_Reactivate
                        fdb     Demo_Object0_Update
                        fdb     Demo_Object0_Draw
                        fdb     0,0             * res2

                        fcb     3               * dataSize
                        fcb     0               * drawType == 0: custom function
                        fcb     3               * initSize
                        fcb     0               * res1
                        fdb     Demo_Object1_Init
                        fdb     Demo_Object1_Reactivate
                        fdb     Demo_Object1_Update
                        fdb     Demo_Object1_Draw
                        fdb     0,0             * res2


