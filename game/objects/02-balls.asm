*********************************************************************************
* DynoSprite - game/objects/02-balls.asm
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

G2OB0       STRUCT
spriteIdx               rmb     1           * the sprite index should always come first with drawType=1
ballType                rmb     1
fracX                   rmb     1
fracY                   rmb     1
velX                    rmd     1
velY                    rmd     1
odometer                rmd     1
            ENDSTRUCT

 IFDEF SPEEDTEST
SpdTestPtr              fdb     0
SpdTestPosTable         fcb     17,0,5,16,-13,9,-13,-9,5,-16
 ENDC

* -----------------------------------------------------------------------------
* -- Object 0 (Marble/Ball) handling functions
* -----------------------------------------------------------------------------

* Object Initialization Function:
* - IN:      X = pointer to Current Object Table for this object instance
*            Y = pointer to Object Descriptor Table for this object type
*            U = pointer to initialization data in object init stream
* - OUT:     none
* - Trashed: all
*
Demo_Grp2Object0_Init
            * copy ball type and calculate initial sprite number
            ldy         COB.statePtr,x
            lda         ,u
            sta         G2OB0.ballType,y
            cmpa        #2
            blo         >                       * jump if static ball type
            suba        #2                      * subtract dynamic ball type offset
            lsra                                * throw away the direction bit
            lsla                                * multiply ball type by 4
            lsla
            adda        #2                      * offset by sprite # for first dynamic ball
!           sta         G2OB0.spriteIdx,y
 IFDEF SPEEDTEST
            * for speed test, put balls in center of screen in circular arrangement
            pshs        y
            ldu         SpdTestPtr,PCR
            cmpx        <Obj_CurrentTablePtr
            bne         >
            leau        SpdTestPosTable,PCR
!           ldd         <Gfx_BkgrndNewX         * background X start is in bytes, but object GlobalX is in pixels
            lslb                                * so we multiply by 2
            rola
            tfr         d,y
            leay        160,y
            ldb         ,u+
            leay        b,y
            sty         COB.globalX,x
            ldy         <Gfx_BkgrndNewY
            leay        100,y
            ldb         ,u+
            leay        b,y
            sty         COB.globalY,x
            stu         SpdTestPtr,PCR
            puls        y
 ELSE
            * generate random X,Y starting coordinate centered on the screen center
            ldd         <Gfx_BkgrndNewX         * background X start is in bytes, but object GlobalX is in pixels
            lslb                                * so we multiply by 2
            rola
            addd        #32+128                 * +128 is because the leau a,u instruction below treats A as signed
            tfr         d,u
            jsr         Util_Random
            leau        a,u                     * add random 8-bit number
            stu         COB.globalX,x
            ldu         <Gfx_BkgrndNewY
            leau        36,u
            jsr         Util_Random
            anda        #127
            leau        a,u
            stu         COB.globalY,x
 ENDC
            * clear fractional position
            clr         G2OB0.fracX,y
            clr         G2OB0.fracY,y
 IFDEF SPEEDTEST
            * for speed test, set velocities to 0
            ldd         #0                      * set velocities to 0 for speed test
            std         G2OB0.velX,y
            std         G2OB0.velY,y
 ELSE
            * set random X,Y velocities between 0.0 and 1.0 pixels/field
            jsr         Util_Random
            pshs        a
            jsr         Util_Random
            pshs        a
            jsr         Util_Random
            pshs        a
            jsr         Util_Random
            puls        b
            anda        #$03
            suba        #2
            std         G2OB0.velX,y
            puls        a,b
            anda        #$03
            suba        #2
            std         G2OB0.velY,y
 ENDC
            * clear the odometer (used for dynamic balls)
            clr         G2OB0.odometer,y
            clr         G2OB0.odometer+1,y
            * write the Current Object Table starting pointer into crash test code below
            ldd         <Obj_CurrentTablePtr
            std         CrashTest_CheckCOTStart+2,PCR
            rts

Demo_Grp2Object0_Reactivate
            rts

* Object Update Function:
* - IN:      X = pointer to Current Object Table for this object instance
*            U = pointer to Object Descriptor Table for this object type
* - OUT:     none
* - Trashed: all
*
Demo_Grp2Object0_Update
            ldy         COB.statePtr,x          * pointer to state data for this object
            * update X coordinate by distance moved
            ldd         G2OB0.velX,y
            tst         <Obj_MotionFactor       * get # of fields to advance the counter value
            bmi         XDone@
            bne         XTimes3@
            lslb
            rola
            bra         XDone@
XTimes3@
            lslb
            rola
            addd        G2OB0.velX,y
XDone@
            std         FrameVelX88@,PCR
            addb        G2OB0.fracX,y
            adca        #0
            stb         G2OB0.fracX,y
            ldu         COB.globalX,x
            leau        a,u
            stu         COB.globalX,x
            * update Y coordinate by distance moved
            ldd         G2OB0.velY,y
            tst         <Obj_MotionFactor       * get # of fields to advance the counter value
            bmi         YDone@
            bne         YTimes3@
            lslb
            rola
            bra         YDone@
YTimes3@
            lslb
            rola
            addd        G2OB0.velY,y
YDone@
            std         <FrameVelY88@,PCR
            addb        G2OB0.fracY,y
            adca        #0
            stb         G2OB0.fracY,y
            ldu         COB.globalY,x
            leau        a,u
            stu         COB.globalY,x
            * test for collisions with other ball objects
            leau        ,x
BallCrashTest@
            leau        -sizeof{COB},u
CrashTest_CheckCOTStart
            cmpu        #0                      * SMC: Current Object Table starting pointer is written here during init
            blo         BallCrashDone@
            ldd         COB.globalX,x
            subd        COB.globalX,u
            bmi         >
            cmpd        #17
            bgt         BallCrashTest@
            bra         TestY@
!           cmpd        #-17
            blt         BallCrashTest@
TestY@
            ldd         COB.globalY,x
            subd        COB.globalY,u
            bmi         >
            cmpd        #17
            bgt         BallCrashTest@
            lbsr        BallCollide
            bra         BallCrashTest@
!           cmpd        #-17
            blt         BallCrashTest@
            lbsr        BallCollide
            bra         BallCrashTest@
BallCrashDone@
            * clip the X coordinate to be in the screen
            ldd         COB.globalX,x
            subd        <Gfx_BkgrndNewX2
            cmpd        #8
            bge         XNoClipL@
            ldd         <Gfx_BkgrndNewX2
            addd        #8
            std         COB.globalX,x
            * VelX = (VelX < 0) ? -VelX+ScreenDeltaX : VelX+ScreenDeltaX
            ldd         G2OB0.velX,y
            bge         >
            NEGATE_D
!           addd        <Demo_ScreenDeltaX88
            std         G2OB0.velX,y
            bra         XClipDone@
*
FrameVelX88@            zmd     1
FrameVelY88@            zmd     1
*
XNoClipL@
            cmpd        #320-9
            bls         XClipDone@
            ldd         <Gfx_BkgrndNewX2
            addd        #320-9
            std         COB.globalX,x
            * VelX = (VelX > 0) ? -VelX+ScreenDeltaX : VelX+ScreenDeltaX
            ldd         G2OB0.velX,y
            ble         >
            NEGATE_D
!           addd        <Demo_ScreenDeltaX88
            std         G2OB0.velX,y
XClipDone@
            * clip the Y coordinate to be in the screen
            ldd         COB.globalY,x
            subd        <Gfx_BkgrndNewY
            cmpd        #8
            bge         YNoClipU@
            ldd         <Gfx_BkgrndNewY
            addd        #8
            std         COB.globalY,x
            * VelY = (VelY < 0) ? -VelY+ScreenDeltaY : VelY+ScreenDeltaY
            ldd         G2OB0.velY,y
            bge         >
            NEGATE_D
!           addd        <Demo_ScreenDeltaY88
            std         G2OB0.velY,y
            bra         YClipDone@
YNoClipU@
            cmpd        #200-9
            bls         YClipDone@
            ldd         <Gfx_BkgrndNewY
            addd        #200-9
            std         COB.globalY,x
            * VelY = (VelY > 0) ? -VelY+ScreenDeltaY : VelY+ScreenDeltaY
            ldd         G2OB0.velY,y
            ble         >
            NEGATE_D
!           addd        <Demo_ScreenDeltaY88
            std         G2OB0.velY,y
YClipDone@
            * calculate the new sprite number
            lda         G2OB0.ballType,y
            suba        #2
            bmi         SpriteIdxDone@
            lsra                                * throw away direction bit
            lsla
            lsla
            adda        #2
            sta         G2OB0.spriteIdx,y       * starting sprite idx for this dynamic ball type
            ldd         G2OB0.odometer,y
            tst         <FrameVelX88@,PCR
            bmi         NegativeVelX@
            addd        <FrameVelX88@,PCR
            bra         odoXDone@
NegativeVelX@
            subd        <FrameVelX88@,PCR
odoXDone@
            tst         <FrameVelY88@,PCR
            bmi         NegativeVelY@
            addd        <FrameVelY88@,PCR
            bra         odoYDone@
NegativeVelY@
            subd        <FrameVelY88@,PCR
odoYDone@
            std         G2OB0.odometer,y
            lsra
            lsra
            lsra
            anda        #3
            ldb         G2OB0.ballType,y
            andb        #1
            beq         spinForward@
            eora        #3
spinForward@
            adda        G2OB0.spriteIdx,y
            sta         G2OB0.spriteIdx,y
SpriteIdxDone@
            * decay the X velocity
            ldd         G2OB0.velX,y
            beq         XDecayDone@
            * velX = velX - (velX >> 8) * MotionFactor
            bpl         >
            inca
            beq         XDecayDone@
*            tsta
*            bne         >
*            inca
!           nega
            tst         <Obj_MotionFactor       * get # of fields to advance the counter value
            bmi         FinishXDecay@
            bne         >
            lsla
            bra         FinishXDecay@
!           sta         <TempByte@,PCR
            lsla
            adda        <TempByte@,PCR
FinishXDecay@
            tfr         a,b
            sex
            addd        G2OB0.velX,y
            std         G2OB0.velX,y
XDecayDone@
            * decay the Y velocity
            ldd         G2OB0.velY,y
            beq         YDecayDone@
            * velY = velY - (velY >> 8) * MotionFactor
            bpl         >
            inca
            beq         YDecayDone@
*            tsta
*            bne         >
*            inca
!           nega
            tst         <Obj_MotionFactor       * get # of fields to advance the counter value
            bmi         FinishYDecay@
            bne         >
            lsla
            bra         FinishYDecay@
!           sta         <TempByte@,PCR
            lsla
            adda        <TempByte@,PCR
FinishYDecay@
            tfr         a,b
            sex
            addd        G2OB0.velY,y
            std         G2OB0.velY,y
YDecayDone@
            rts
TempByte@               zmb     1


* Ball Collision Handling function
* - IN:      X = pointer to Current Object Table for object being processed
*            Y = pointer to state data for object being processed
*            U = pointer to Current Object Table for object already processed which is colliding with current object
* - OUT:     none
* - Trashed: D
*
CalcVecProjection@
            * start by decomposing ScalarProjection88@ value into sign and absolute value
            clr         <ScalarProjectionSgn@,PCR
            ldd         <ScalarProjection88@,PCR
            bpl         >
            com         <ScalarProjectionSgn@,PCR
            NEGATE_D
            std         <ScalarProjection88@,PCR
            * do 16x8 multiply to get X component of vector projection
!           lda         BallDeltaNormX@,PCR
            mul
            lslb
            rola
            sta         <ProjectionTemp@+1,PCR
            lda         <ScalarProjection88@,PCR
            ldb         BallDeltaNormX@,PCR
            mul
            lslb
            rola
            addb        <ProjectionTemp@+1,PCR
            adca        #0
            std         ,y                      * X component is stored at Y pointer
            lda         <ScalarProjectionSgn@,PCR
            eora        BallDiffXSgn@,PCR
            beq         >
            ldd         ,y
            NEGATE_D
            std         ,y
            * do 16x8 multiply to get Y component of vector projection
!           lda         BallDeltaNormY@,PCR
            ldb         <ScalarProjection88@+1,PCR
            mul
            lslb
            rola
            sta         <ProjectionTemp@+1,PCR
            lda         <ScalarProjection88@,PCR
            ldb         BallDeltaNormY@,PCR
            mul
            lslb
            rola
            addb        <ProjectionTemp@+1,PCR
            adca        #0
            std         2,y                     * Y component is stored at Y+2 pointer
            lda         <ScalarProjectionSgn@,PCR
            eora        <BallDiffYSgn@,PCR
            beq         >
            ldd         2,y
            NEGATE_D
            std         2,y
!           rts
*
ProjVecSgn@             zmb     1
ProjectionTemp@         zmd     1
ScalarProjection88@     zmd     1
ScalarProjectionSgn@    zmb     1
*
CalcProjectionX@
            tsta                                * is initial X velocity negative?
            bpl         >
            com         <ProjVecSgn@,PCR       * yes, so flip sign of projected velocity vector
            NEGATE_D
!           std         <ProjectionTemp@,PCR
            lda         <BallDeltaNormX@,PCR
            mul
            lslb
            rola
            sta         <ProjectionTemp@+1,PCR
            lda         <ProjectionTemp@,PCR
            ldb         <BallDeltaNormX@,PCR
            mul
            lslb
            rola
            addb        <ProjectionTemp@+1,PCR
            adca        #0
            tst         <ProjVecSgn@,PCR
            beq         >
            NEGATE_D
!           ADD_D_TO_Y
            rts
CalcProjectionY@
            tsta                                * is initial Y velocity negative?
            bpl         >
            com         <ProjVecSgn@,PCR       * yes, so flip sign of projected velocity vector
            NEGATE_D
!           std         <ProjectionTemp@,PCR
            lda         <BallDeltaNormY@,PCR
            mul
            lslb
            rola
            sta         <ProjectionTemp@+1,PCR
            lda         <ProjectionTemp@,PCR
            ldb         <BallDeltaNormY@,PCR
            mul
            lslb
            rola
            addb        <ProjectionTemp@+1,PCR
            adca        #0
            tst         <ProjVecSgn@,PCR
            beq         >
            NEGATE_D
!           ADD_D_TO_Y
            rts
*
BallDiffXSgn@           zmb     1
BallDiffXAbs@           zmb     1
BallDiffYSgn@           zmb     1
BallDiffYAbs@           zmb     1
BallDiffSq@             zmd     1
BallDeltaNormX@         zmb     1
BallDeltaNormY@         zmb     1
BallVelXSgn@            zmb     1
BallVelYSgn@            zmb     1
*
BallCollide
            * calculate sign and magnitude of ball position difference in X and Y dimensions
            ldd         COB.globalX,x
            subd        COB.globalX,u
            blo         DiffXNeg@
            clra
            bra         StoreDiffX@
DiffXNeg@
            lda         #$ff
            negb
StoreDiffX@
            std         <BallDiffXSgn@,PCR
            lda         <BallDiffXAbs@,PCR
            mul
            std         <BallDiffSq@,PCR
            ldd         COB.globalY,x
            subd        COB.globalY,u
            blo         DiffYNeg@
            clra
            bra         StoreDiffY@
DiffYNeg@
            lda         #$ff
            negb
StoreDiffY@
            std         <BallDiffYSgn@,PCR
            * calculate distance squared and bail out if > 17 or < 5
            lda         <BallDiffYAbs@,PCR
            mul
            addd        <BallDiffSq@,PCR
            cmpd        #289
            bls         >
            rts
!           cmpd        #25
            bhs         >
            rts
!           std         <BallDiffSq@,PCR
            pshs        x,y,u
            pshs        d,x,y,u
            ldb         #1
            jsr         Sound_Play
            puls        d,x,y,u
            * calculate unit vector (in 1.7 fixed-point format) between ball objects
            tfr         x,y
            leax        InvSqRoot17,PCR
            ADD_D_TO_X
            lda         <BallDiffXAbs@,PCR
            ldb         ,x
            mul
            stb         <BallDeltaNormX@,PCR
            lda         <BallDiffYAbs@,PCR
            ldb         ,x
            mul
            stb         <BallDeltaNormY@,PCR
            * fix the position of the current object 17 pixels away from the older object
            lda         #68                     * 17 * 4
            mul
            inca
            lsra
            tst         <BallDiffYSgn@,PCR
            beq         >
            nega
!           tfr         a,b
            sex
            addd        COB.globalY,u
            std         COB.globalY,y
            ldb         <BallDeltaNormX@,PCR
            lda         #68                     * 17 * 4
            mul
            inca
            lsra
            tst         BallDiffXSgn@,PCR
            beq         >
            nega
!           tfr         a,b
            sex
            addd        COB.globalX,u
            std         COB.globalX,y
            * calculate the part of each ball's velocity which is parallel to the vector between their positions
            ldx         COB.statePtr,y
            ldu         COB.statePtr,u
            ldy         #0                      * Y is accumulator for scalar projection
            lda         BallDiffXSgn@,PCR
            sta         ProjVecSgn@,PCR
            ldd         G2OB0.velX,x
            lbsr        CalcProjectionX@        * calculate X component of scalar projection
            lda         BallDiffYSgn@,PCR
            sta         ProjVecSgn@,PCR
            ldd         G2OB0.velY,x
            lbsr        CalcProjectionY@        * calculate Y component of scalar projection
            sty         ScalarProjection88@,PCR
            leay        <Ball0ParVelX@,PCR
            lbsr        CalcVecProjection@      * multiply scalar projection value by unit ball position delta
            ldy         #0
            lda         BallDiffXSgn@,PCR
            sta         ProjVecSgn@,PCR
            ldd         G2OB0.velX,u
            lbsr        CalcProjectionX@
            lda         BallDiffYSgn@,PCR
            sta         ProjVecSgn@,PCR
            ldd         G2OB0.velY,u
            lbsr        CalcProjectionY@
            sty         ScalarProjection88@,PCR
            leay        <Ball1ParVelX@,PCR
            lbsr        CalcVecProjection@
            * calculate new velocities for each ball
            ldd         G2OB0.velX,x
            subd        <Ball0ParVelX@,PCR
            addd        <Ball1ParVelX@,PCR
            std         G2OB0.velX,x
            ldd         G2OB0.velY,x
            subd        <Ball0ParVelY@,PCR
            addd        <Ball1ParVelY@,PCR
            std         G2OB0.velY,x
            ldd         G2OB0.velX,u
            subd        <Ball1ParVelX@,PCR
            addd        <Ball0ParVelX@,PCR
            std         G2OB0.velX,u
            ldd         G2OB0.velY,u
            subd        <Ball1ParVelY@,PCR
            addd        <Ball0ParVelY@,PCR
            std         G2OB0.velY,u
            puls        x,y,u
            rts
*
Ball0ParVelX@           zmd     1
Ball0ParVelY@           zmd     1
Ball1ParVelX@           zmd     1
Ball1ParVelY@           zmd     1

* -----------------------------------------------------------------------------
* -- Data tables
* -----------------------------------------------------------------------------

InvSqRoot17             fcb     $00,$80,$5b,$4a,$40,$39,$34,$30,$2d,$2b,$28,$27,$25,$24,$22,$21
                        fcb     $20,$1f,$1e,$1d,$1d,$1c,$1b,$1b,$1a,$1a,$19,$19,$18,$18,$17,$17
                        fcb     $17,$16,$16,$16,$15,$15,$15,$14,$14,$14,$14,$14,$13,$13,$13,$13
                        fcb     $12,$12,$12,$12,$12,$12,$11,$11,$11,$11,$11,$11,$11,$10,$10,$10
                        fcb     $10,$10,$10,$10,$10,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0e,$0e
                        fcb     $0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0d,$0d,$0d,$0d,$0d,$0d
                        fcb     $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d,$0c,$0c,$0c,$0c,$0c,$0c,$0c
                        fcb     $0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0b,$0b,$0b,$0b
                        fcb     $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
                        fcb     $0b,$0b,$0b,$0b,$0b,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a
                        fcb     $0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a
                        fcb     $0a,$0a,$0a,$0a,$0a,$0a,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09
                        fcb     $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09
                        fcb     $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09
                        fcb     $09,$09,$09,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08
                        fcb     $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08
                        fcb     $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08
                        fcb     $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08
                        fcb     $08,$08,$08,$08,$07,$07,$07,$07,$07,$07,$07,$07


* -----------------------------------------------------------------------------
* -- Object Descriptor Table must come after the code block
* -----------------------------------------------------------------------------

NumberOfObjects         fcb     1
ObjectDescriptorTable
                        fcb     sizeof{G2OB0}   * dataSize
                        fcb     1               * drawType == 1: standard sprite w/ no rowcrop
                        fcb     1               * initSize
                        fcb     0               * res1
                        fdb     Demo_Grp2Object0_Init
                        fdb     Demo_Grp2Object0_Reactivate
                        fdb     Demo_Grp2Object0_Update
                        fdb     0               * custom draw function
                        fdb     0               * vpageAddr
                        fdb     0,0             * res2


