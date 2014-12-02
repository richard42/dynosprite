*********************************************************************************
* DynoSprite - system.asm
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

* PIA default register value definitions
* CA1/CB1 are always interrupts, CA2/CB2 are always outputs
PIA0A_Ctrl          equ     %00110100           * CA2 = DAC SELA (low), Data Register, CA1 = HSync interrupt active low disabled
PIA0B_Ctrl          equ     %00110100           * CB2 = DAC SELB (low), Data Register, CB1 = VSync interrupt active low disabled
PIA0A_DDR           equ     %00000000           * PA0-PA6: keyboard row inputs, PA7: comparator input from DAC chip SC77526
PIA0B_DDR           equ     %11111111           * PB0-PB7: keyboard column outputs
PIA1A_Ctrl          equ     %00110100           * CA2 = Cass relay (low), Data Register, CA1 = Serial pin 1 DCD active low disabled
PIA1B_Ctrl          equ     %00111100           * CB2 = Audio enable (hi), Data Register, CB1 = Cartridge active low disabled
PIA1A_DDR           equ     %11111110           * PA0: cassette 0-cross input, PA1: RS232 data output, PA2-PA7: outputs to DAC
PIA1B_DDR           equ     %11110000           * PB0: from Serial pin 2, PB1: from DAC audio out, PB2: from PIA0 PB6
                                                * PB3: RGB connected input, PB4-PB7: unconnected (output)


***********************************************************
* System_InitHardware:
* - IN:      
* - OUT:     
* - Trashed: A
***********************************************************
System_InitHardware
            clr         $FFD9                   * turbo cpu frequency
 IFEQ CPU-6309
            * put 6309 into enhanced mode
            ldmd        #1
            * Sorry Color BASIC, but we gotta trash ENDFLG, CHARAC, and ENDCUR
            * in order to install the Divide-by-0/Illegal Opcode interrupt for the 6309
            lda         #$7E                    * JMP extended
            sta         >$0000
            ldd         #System_InterruptDIV0
            std         >$0001
 ENDIF
            orcc        #$50                    * disabled interrupts
            lda         #$FC                    * coco2 gfx, MMU enabled, coco3 IRQ and FIRQ handling enabled
                                                * fix $FE** page to high ram, standard SCS, rom: 16k internal / 16k cartridge
            sta         $FF90                   * set GIME init register 0
            * initialize PIA0 state
            lda         #(PIA0A_Ctrl&$FB)       * select data direction A
            sta         $FF01
            lda         #(PIA0A_DDR)            * set DDRA for PIA0
            sta         $FF00
            lda         #(PIA0A_Ctrl)           * set CA1/CA2 pin modes, data register
            sta         $FF01
            lda         #(PIA0B_Ctrl&$FB)       * select data direction B
            sta         $FF03
            lda         #(PIA0B_DDR)            * set DDRB for PIA0
            sta         $FF02
            lda         #(PIA0B_Ctrl)           * set CB1/CB2 pin modes, data register
            sta         $FF03
            * initialize PIA1 state
            lda         #(PIA1A_Ctrl&$FB)       * select data direction A
            sta         $FF21
            lda         #(PIA1A_DDR)            * set DDRA for PIA1
            sta         $FF20
            lda         #(PIA1A_Ctrl)           * set CA1/CA2 pin modes, data register
            sta         $FF21
            lda         #(PIA1B_Ctrl&$FB)       * select data direction B
            sta         $FF23
            lda         #(PIA1B_DDR)            * set DDRB for PIA1
            sta         $FF22
 IFEQ SOUND_METHOD-1
            lda         #(PIA1B_Ctrl|$08)       * set CB1/CB2 pin modes, data register
            sta         $FF23
            lda         #$82
            sta         $FF20                   * set DAC to mid-range, serial bit to 1
 ENDC
 IFEQ SOUND_METHOD-2
            lda         #(PIA1B_Ctrl&$F7)       * clear CB2 output (disable audio on SC77526 chip)
            sta         $FF23
 ENDC
            * set Orchestra-90 DACs to mid-range, just in case they will be used
            lda         #$80
            sta         $FF7A
            sta         $FF7B
            * read both PIA data registers to clear any fired interrupts
            lda         $FF00
            lda         $FF02
            lda         $FF20
            lda         $FF22
            * Note that $FF92/93 are only writeable
            * Reading them will return the state of the hardware signals
            * It will not tell you which IRQs are enabled
            clr         $FF92                   * disable all IRQs
            clr         $FF93                   * disable all FIRQs
            ldd         #(System_InterruptSWI+$103)
            std         $FEFB                   * replace SWI vector with "lbra System_InterruptSWI"
            andcc       #$AF                    * re-enable interrupts
            clr         $FF40                   * turn off drive motor
            clr         $986                    * clear DGRAM also, so Disk BASIC knows that drive motor was shut off
            rts


***********************************************************
* System_UnInit:
* - IN:      
* - OUT:     
* - Trashed: A
***********************************************************
*System_UnInit
*            orcc        #$50                    * disabled interrupts
*                                                * load GIME init register 0.  MMU should already be enabled
*            lda         #$CC                    * coco2 gfx, MMU enabled, disable coco3 IRQ/FIRQ
*                                                * fix $FE** page to high ram, SCS enabled, rom: 16k internal/16k cart
*            sta         $FF90
*            ldd         #$0212
*            std         $FEF8                   * restore "lbra $010c" IRQ vector
*            lda         #$35
*            sta         $FF03                   * restore PIA1 VSYNC IRQ
*            clra
*            tfr         a,dp                    * set DP to 0 page
*            andcc       #$AF                    * re-enable interrupts
*            rts

***********************************************************
* System_EnterDiskMode:
* - IN:      
* - OUT:     
* - Trashed: A
***********************************************************
System_EnterDiskMode
            lda         <MemMgr_VirtualTable+VH_BASIC0
            sta         $FFA0                   * map BASIC page 0 to $0000 (variables needed for disk basic rom)
            lda         <MemMgr_VirtualTable+VH_BASICROM
            sta         $FFA5                   * map the 8k Color BASIC ROM block into 6809 address space at $A000
            lda         <MemMgr_VirtualTable+VH_DSKROM
            sta         $FFA6                   * map the 8k Disk BASIC ROM block into 6809 address space at $C000
            rts

***********************************************************
* System_LeaveDiskMode:
* - IN:      
* - OUT:     
* - Trashed: A
***********************************************************
System_LeaveDiskMode
            rts

***********************************************************
* System_CallDSKCON:
* - IN:      
* - OUT:     X = Pointer to DSKCON parameter block
* - Trashed: A,B,Y,U
***********************************************************
System_CallDSKCON
            lda         <MemMgr_VirtualTable+VH_HIGHROM
            sta         $FFA7                   * map the high ROM page back to $E000 for the disk call (needed for CoCoNET MicroSD Pak)
            pshs        dp                      * save original DP register
            clra
            tfr         a,dp                    * set DP to 0 for disk basic rom
 IFEQ CPU-6309
            ldmd        #0                      * for 6309, go back to 'emulation' mode
 ENDC
            clr         $FFD8                   * slow cpu back to 0.9MHz for disk read
            jsr         [$C004]                 * read sector
            puls        dp                      * restore DP so we can access direct variables
            lda         <MemMgr_VirtualTable+VH_CODE2
            sta         $FFA7                   * re-map secondary code page to $E000 in case we throw SWI below
            ldx         $C006                   * get pointer to DSKCON parameter block
            tst         DC.STA,x
            beq         >                       * branch if no error
            lda         DC.STA,x
            clr         $FF40                   * turn off drive motor
            swi
!           clr         $FFD9                   * back to turbo cpu frequency
 IFEQ CPU-6309
            ldmd        #1                      * for 6309, go to 'native' mode (enhanced)
 ENDC
            rts

***********************************************************
* System_EnableGraphics:
* - IN:      
* - OUT:     
* - Trashed: A, B
***********************************************************
System_EnableGraphics
            orcc        #$50                    * disable interrupts
            lda         #$7C                    * Coco3 gfx, MMU enabled, coco3 IRQ/FIRQ enabled
                                                * fix $FE** page to high ram, standard SCS, rom: 16k internal/16k cartridge
            sta         $FF90
            lda         #$20                    * 64k memory chips, 279nsec timer input, MMU register bank 0
            sta         $FF91
            lda         #$80                    * graphics mode, color output, 60 hz, max vertical res
            sta         $FF98
 IFDEF VISUALTIME
            lda         #$3A                    * 256 x 200 x 16 color
 ELSE
            lda         #$3E                    * 320 x 200 x 16 color
 ENDC
            sta         $FF99
            clr         $FF9C                   * clear vertical scroll (only used for text modes)
            lda         #$08                    * enable Vertical Border interrupt
            sta         $FF93                   * write GIME FIRQ register
            ldd         #(System_InterruptFIRQ_NoSound+$109)
            std         $FEF5                   * replace FIRQ vector with "lbra System_InterruptFIRQ_NoSound"
            andcc       #$AF                    * re-enable interrupts
            rts

***********************************************************
* System_SetPaletteConst:
* - IN:      A=value to store
* - OUT:     
* - Trashed: B,X
***********************************************************
System_SetPaletteConst
            ldx         #$FFB0                  * set palette to constant value
            ldb         #16
!           sta         ,x+
            decb
            bne         <
            rts

***********************************************************
* System_SetPaletteAuto:
*   This function loads either the RGB or Composite palette from the
*   Gfx_Palette_CMP_RGB table, based upon the value of the Gfx_MonitorIsRGB flag
*
* - IN:      None
* - OUT: 
* - Trashed: A,B,X,Y
***********************************************************

System_SetPaletteAuto
            ldx         #Gfx_Palette_CMP_RGB
            tst         <Gfx_MonitorIsRGB
            beq         >
            leax        16,x
!           ldy         #$FFB0
            ldb         #16                     * set 16 palette entries
!           lda         ,x+
            sta         ,y+
            decb
            bne         <
            rts

***********************************************************
* System_EnableAudioInterrupt:
*   This function enables the Timer FIRQ signal, which is used for audio
*   output.  Graphics mode must already be enabled before calling this.
*   The timer input clock is 3.579545 MHz.
*
* - IN:      D = Timer countdown value (0 - 4095), DP may be invalid
* - OUT:     
* - Trashed: A
***********************************************************
System_EnableAudioInterrupt
            orcc        #$50                    * disable interrupts
            stb         $FF95
            sta         $FF94                   * start timer
            lda         #$28                    * enable Timer and Vertical Border interrupts
            sta         $FF93                   * write GIME FIRQ register
            ldd         #(System_InterruptFIRQ_DAC6+$109)
            tst         Sound_OutputMode
            beq         >
            ldd         #(System_InterruptFIRQ_Orc90+$109)
!           std         $FEF5                   * replace FIRQ vector with "lbra System_InterruptFIRQ_*"
            andcc       #$AF                    * re-enable interrupts
            rts

***********************************************************
* System_DisableAudioInterrupt:
*
* - IN:      Interrupts should already be disabled (orcc #$50)
* - OUT:     
* - Trashed: A
***********************************************************
System_DisableAudioInterrupt
            clr         $FF95
            clr         $FF94                   * stop timer
            lda         #$08                    * enable Vertical Border interrupt only
            sta         $FF93                   * write GIME FIRQ register
            ldd         #(System_InterruptFIRQ_NoSound+$109)
            std         $FEF5                   * replace FIRQ vector with "lbra System_InterruptFIRQ_NoSound"
            rts

***********************************************************
* System_InterruptFIRQ:
***********************************************************
*
System_SndBufferPtr      zmd     1
*
System_InterruptFIRQ_DAC6
            pshs        a
            lda         $FF93                   * reset GIME FIRQ and read which signal caused this FIRQ
            bita        #$08
            bne         CC3VSync@               * jump if this is a VSYNC interrupt
            * audio code goes here
            lda         [<System_SndBufferPtr,PCR]
            sta         $FF20
            inc         <System_SndBufferPtr+1,PCR
            beq         AudioBufferRefill@
            puls        a
            rti
AudioBufferRefill@
            pshs        b,x,y,u
            jsr         Sound_RefillBuffer
            puls        b,x,y,u
            puls        a
            rti
System_InterruptFIRQ_Orc90
            pshs        a
            lda         $FF93                   * reset GIME FIRQ and read which signal caused this FIRQ
            bita        #$08
            bne         CC3VSync@               * jump if this is a VSYNC interrupt
            * audio code goes here
            lda         [<System_SndBufferPtr,PCR]
            sta         $FF7A
            sta         $FF7B
            inc         <System_SndBufferPtr+1,PCR
            beq         AudioBufferRefill@
            puls        a
            rti
System_InterruptFIRQ_NoSound
            pshs        a
            lda         $FF93                   * reset GIME FIRQ and read which signal caused this FIRQ
            bita        #$08
            bne         CC3VSync@               * jump if this is a VSYNC interrupt
            * theoretically we shouldn't get here because only the VSync FIRQ should be active.  but
            * there might be some corner cases during audio startup/shutdown which would lead us here
            puls        a
            rti
CC3VSync@
            pshs        b,x,y
            ldb         Gfx_LastRenderedFrame
            cmpb        Gfx_DisplayedFrame
            bne         NewFrame@
            * if there is no new frame to draw, we are too slow and skipped a frame
            inc         Gfx_CurrentFieldCount
 IFDEF VISUALTIME
            lda         Gfx_CurrentFieldCount
            cmpa        #1
            beq         BorderGreen@
            cmpa        #2
            beq         BorderRed@
BorderWhite@
            lda         #63                     * set a white video screen border to indicate 4+ field duration
            sta         $FF9A
            bra         EndCC3VSync@
BorderGreen@
            lda         #18                     * set a green video screen border to indicate 2 field duration
            sta         $FF9A
            bra         EndCC3VSync@
BorderRed@
            lda         #22                     * set a red video screen border to indicate 3 field duration
            sta         $FF9A
 ENDC
EndCC3VSync@
            puls        b,x,y
            puls        a
            rti
NewFrame@
            clr         Gfx_CurrentFieldCount   * reset the field counter
 IFDEF VISUALTIME
            lda         #27                     * set a dark blue border color to indicate computation in progress
            sta         $FF9A
 ENDC
            * we have a new frame to display, so update the GIME video start address
            stb         Gfx_DisplayedFrame
            andb        #1                      * double buffered, so low bit in frame number gives the buffer pair to use
            bsr         System_SetVideoStart
            bra         EndCC3VSync@


***********************************************************
* System_SetVideoStart:
*   This function sets the GIME Vertical Start Offset value to the correct
*   value for the frame in the buffer pair given by input register B
*
* - IN:      B=Buffer Pair (0 or 1)
* - OUT:     A=Horizontal Offset Register value ($80-$83)
*            Y=Vertical Start Offset value (512k physical address divided by 8)
*            X=pointer to X,Y values (16 bits) for this Buffer Pair in Gfx_BkgrndStartXYList table
* - Trashed: B
***********************************************************
System_SetVideoStart
            ldy         #0                      * guess that we will use buffer pair 0
            tstb
            beq         >
            ldy         #$3800                  * buffer pair 1 is 14 8k pages later
!           ldx         #Gfx_BkgrndStartXYList
            lslb
            lslb
            abx                                 * X is pointer to X,Y playmap coordinates for this buffer pair
            ldd         2,x                     * Buffer 0 Y
            * Rows are 256 bytes, so Y coordinates must be << 8 to calculate physical byte address
            * However, I want to calculate the address in units of 8 bytes, so I only << 5
            aslb
            rola
            aslb
            rola
            aslb
            rola
            aslb
            rola
            aslb
            rola
            ADD_D_TO_Y
            ldd         ,x                      * Buffer 0 X
            * divide X value by 8 (shift right by 3)
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb                                * Now D is X >> 3
            ADD_D_TO_Y
            lda         1,x                     * get low byte of X coordinate
            bita        #1                      * should we use the odd buffer?
            beq         EvenBuffer@
OddBuffer@
            leay        7168,y                  * advance vertical start to 'odd' buffer, which is 7 8k pages after even
EvenBuffer@
            leay        6,y                     * add 6 * 8 = 48 bytes to get to center of row stride (256-160)/2
            sty         $FF9D                   * set GIME vertical offset register
            lsra
            anda        #3
            ora         #$80                    * set Horizontal virtual screen enable (256-byte rows)
            sta         $FF9F                   * set GIME horizontal offset register
            rts

* offsets to registers in stack after exception
STACKOFF_A              EQU     1
STACKOFF_B              EQU     2
 IFEQ CPU-6309
STACKOFF_E              EQU     3
STACKOFF_F              EQU     4
STACKOFF_DP             EQU     5
STACKOFF_X              EQU     6
STACKOFF_Y              EQU     7
STACKOFF_U              EQU     10
STACKOFF_PC             EQU     12
 ELSE
STACKOFF_DP             EQU     3
STACKOFF_X              EQU     4
STACKOFF_Y              EQU     6
STACKOFF_U              EQU     8
STACKOFF_PC             EQU     10
 ENDC


***********************************************************
* System_PrintError
***********************************************************
* Locals:
*
Msg_Line1@  fcn         '**** Error (PC=0000 DP=00)'
 IFEQ CPU-6309
Msg_Line2@  fcn         'A=00 B=00 E=00 F=00'
 ELSE
Msg_Line2@  fcn         'A=00 B=00'
 ENDC
Msg_Line3@  fcn         'X=0000 Y=0000 U=0000 S=0000'
*
System_PrintError
            ldd         ,x                      * write error type (4 characters) into Msg_Line1
            std         Msg_Line1@
            ldd         2,x
            std         Msg_Line1@+2
            lda         #$20                    * just in case DP got messed up
            tfr         a,dp
            ldd         STACKOFF_PC,s           * load address of next instruction after one which threw exception into X
            ldx         #Msg_Line1@+15
            jsr         Util_WordToAsciiHex     * write PC location into message string
            lda         STACKOFF_DP,s
            leax        8,x
            jsr         Util_ByteToAsciiHex     * write DP register value
            lda         STACKOFF_A,s
            ldx         #Msg_Line2@+2
            jsr         Util_ByteToAsciiHex     * write A register value
            lda         STACKOFF_B,s
            leax        5,x
            jsr         Util_ByteToAsciiHex     * write B register value
 IFEQ CPU-6309
            lda         STACKOFF_E,s
            leax        5,x
            jsr         Util_ByteToAsciiHex     * write E register value
            lda         STACKOFF_F,s
            leax        5,x
            jsr         Util_ByteToAsciiHex     * write F register value
 ENDC
            ldd         STACKOFF_X,s
            ldx         #Msg_Line3@+2
            jsr         Util_WordToAsciiHex     * write X register value
            ldd         STACKOFF_Y,s
            leax        7,x
            jsr         Util_WordToAsciiHex     * write Y register value
            ldd         STACKOFF_U,s
            leax        7,x
            jsr         Util_WordToAsciiHex     * write U register value
            tfr         s,d
            addd        #STACKOFF_PC+2          * adjust stack pointer to value before exception
            leax        7,x
            jsr         Util_WordToAsciiHex     * write S register value
            orcc        #$50                    * permanently disable interrupts
            * in case we crash before the GIME start registers were set up, set them now
            ldb         Gfx_DisplayedFrame
            andb        #1
            lslb
            lslb
            ldx         #Gfx_BkgrndStartXYList
            abx
            jsr         Gfx_UpdatePhyAddress
            ldb         Gfx_DisplayedFrame
            andb        #1
            jsr         System_SetVideoStart
            * set color 0 to black, and 15 to white
            clr         $FFB0
            lda         #63
            sta         $FFBF
            * draw Line 1
            lda         #2                      * Y=2
            ldb         #8                      * X=16 (8 bytes)
            ldx         #Msg_Line1@
            ldu         #0
            jsr         Gfx_DrawTextLine        * print error message at top left of screen
            lda         #1                      * Y=1
            ldb         #7                      * X=14 (4 bytes)
            ldx         #Msg_Line1@
            ldu         #0
            jsr         Gfx_DrawTextLine        * print error message at top left of screen
            lda         #1                      * Y=1
            ldb         #8                      * X=16 (8 bytes)
            ldx         #Msg_Line1@
            ldu         #15
            jsr         Gfx_DrawTextLine        * print error message at top left of screen
            * draw Line 2
            lda         #17                     * Y=17
            ldb         #8                      * X=16 (8 bytes)
            ldx         #Msg_Line2@
            ldu         #0
            jsr         Gfx_DrawTextLine        * print error message at top left of screen
            lda         #16                     * Y=16
            ldb         #7                      * X=14 (7 bytes)
            ldx         #Msg_Line2@
            ldu         #0
            jsr         Gfx_DrawTextLine        * print error message at top left of screen
            lda         #16                     * Y=16
            ldb         #8                      * X=16 (8 bytes)
            ldx         #Msg_Line2@
            ldu         #15
            jsr         Gfx_DrawTextLine        * print error message at top left of screen
            * draw Line 3
            lda         #32                     * Y=32
            ldb         #8                      * X=16 (8 bytes)
            ldx         #Msg_Line3@
            ldu         #0
            jsr         Gfx_DrawTextLine        * print error message at top left of screen
            lda         #31                     * Y=31
            ldb         #7                      * X=14 (7 bytes)
            ldx         #Msg_Line3@
            ldu         #0
            jsr         Gfx_DrawTextLine        * print error message at top left of screen
            lda         #31                     * Y=31
            ldb         #8                      * X=16 (8 bytes)
            ldx         #Msg_Line3@
            ldu         #15
            jsr         Gfx_DrawTextLine        * print error message at top left of screen
SWILoop@
            bra         SWILoop@


***********************************************************
* System_InterruptSWI:
***********************************************************
*
ErrorTag@   fcc         'SWI '
*
System_InterruptSWI
            ldx         #ErrorTag@
            jmp         System_PrintError

***********************************************************
* System_InterruptDIV0:
***********************************************************
*
Div0Tag@    fcc         'DIV0'
IlOpTag@    fcc         'IlOp'
*
System_InterruptDIV0
            bitmd       #$80
            bne         DivBy0@
            ldx         #IlOpTag@
            jmp         System_PrintError
DivBy0@
            ldx         #Div0Tag@
            jmp         System_PrintError

