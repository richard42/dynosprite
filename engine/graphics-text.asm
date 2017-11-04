*********************************************************************************
* DynoSprite - graphics-text.asm
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
* Gfx_DrawTextLine:
*
* - IN:      A=Y coordinate in rows (0-199)
*            B=X coordinate in bytes (pixel pairs, 0-159)
*            X=pointer to NULL-terminated string
*            U=color (4 bits)
* - OUT:     N/A
* - Trashed: A,B,X,Y,U
***********************************************************
*
Gfx_DrawTextLine_Back
            pshs        x
            jsr         Gfx_GetPixelAddress_Back      * start by getting starting memory location
            bra         MapScreenWindow@
Gfx_DrawTextLine
            pshs        x
            jsr         Gfx_GetPixelAddress_Front     * start by getting starting memory location
MapScreenWindow@
            tfr         a,b
            incb
            std         $FFA3                   * map screen buffer to $6000-$9FFF
            leay        $6000,y                 * Y now points to starting destination byte
            tfr         u,d                     * color is in 4 low bits of B
            stb         ColorMaskVal@+3
            lslb
            lslb
            lslb
            lslb
            stb         ColorMaskVal@+5
            orb         ColorMaskVal@+3
            stb         ColorMaskVal@+7
LetterLoop@
            puls        u
            ldb         ,u+                     * get next character
            bne         >                       * if non-0 character, continue forward
            rts                                 * otherwise we're done
*
* Locals
ColorMaskVal@   fcb     $ff,$00,$f0,$00,$0f,$00,$00,$00
RowCounter@     rmb     1
*
!           pshs        u
            subb        #$20                    * first printable character map is 32
            ldx         #Gfx_FontData
            ldu         #ColorMaskVal@
            lda         #13
            mul
            ADD_D_TO_X                          * X is pointer to 8x13 bitmap for current character
            lda         #13
            sta         RowCounter@
RowLoop@
            lda         ,x
            anda        #$c0
            beq         SkipByte0@              * skip this byte
            lsla
            rola
            rola
            rola
            ldb         ,y
            andb        a,u
            inca
            orb         a,u
            stb         ,y
SkipByte0@
            lda         ,x
            anda        #$30
            beq         SkipByte1@              * skip this byte
            lsra
            lsra
            lsra
            ldb         1,y
            andb        a,u
            inca
            orb         a,u
            stb         1,y
SkipByte1@
            lda         ,x
            anda        #$0c
            beq         SkipByte2@              * skip this byte
            lsra
            ldb         2,y
            andb        a,u
            inca
            orb         a,u
            stb         2,y
SkipByte2@
            lda         ,x
            anda        #$03
            beq         SkipByte3@              * skip this byte
            lsla
            ldb         3,y
            andb        a,u
            inca
            orb         a,u
!           stb         3,y
SkipByte3@
            leax        1,x                     * advance bitmap pointer to next row
            leay        256,y                   * advance destination pixel pointer to next line
            dec         RowCounter@
            bne         RowLoop@
            leay        -3324,y                 * move pixel pointer up 13 rows and right 8 pixels (4 bytes)
            bra        LetterLoop@              * do next character in line

            * font data were generated with: hexdump -e '"            fcb     " 16/1 "$%02X," "\n"' ~/Desktop/pgcfont.bin > ../font.asm
Gfx_FontData
            fcb     $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$18,$3C,$3C,$3C,$18,$18,$00,$18,$18,$00,$00
            fcb     $00,$66,$66,$66,$24,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$6C,$6C,$FE,$6C,$6C,$6C,$FE,$6C,$6C,$00,$00
            fcb     $18,$18,$7C,$C6,$C2,$C0,$7C,$06,$86,$C6,$7C,$18,$18
            fcb     $00,$00,$00,$00,$C2,$C6,$0C,$18,$30,$66,$C6,$00,$00
            fcb     $00,$00,$38,$6C,$6C,$38,$76,$DC,$CC,$CC,$76,$00,$00
            fcb     $00,$30,$30,$30,$60,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$0C,$18,$30,$30,$30,$30,$30,$18,$0C,$00,$00
            fcb     $00,$00,$30,$18,$0C,$0C,$0C,$0C,$0C,$18,$30,$00,$00
            fcb     $00,$00,$00,$00,$66,$3C,$FF,$3C,$66,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$18,$18,$7E,$18,$18,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00,$18,$18,$18,$30,$00
            fcb     $00,$00,$00,$00,$00,$00,$FE,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00,$00,$18,$18,$00,$00
            fcb     $00,$00,$02,$06,$0C,$18,$30,$60,$C0,$80,$00,$00,$00
            fcb     $00,$00,$7C,$C6,$CE,$DE,$F6,$E6,$C6,$C6,$7C,$00,$00
            fcb     $00,$00,$18,$38,$78,$18,$18,$18,$18,$18,$7E,$00,$00
            fcb     $00,$00,$7C,$C6,$06,$0C,$18,$30,$60,$C6,$FE,$00,$00
            fcb     $00,$00,$7C,$C6,$06,$06,$3C,$06,$06,$C6,$7C,$00,$00
            fcb     $00,$00,$0C,$1C,$3C,$6C,$CC,$FE,$0C,$0C,$1E,$00,$00
            fcb     $00,$00,$FE,$C0,$C0,$C0,$FC,$06,$06,$C6,$7C,$00,$00
            fcb     $00,$00,$38,$60,$C0,$C0,$FC,$C6,$C6,$C6,$7C,$00,$00
            fcb     $00,$00,$FE,$C6,$06,$0C,$18,$30,$30,$30,$30,$00,$00
            fcb     $00,$00,$7C,$C6,$C6,$C6,$7C,$C6,$C6,$C6,$7C,$00,$00
            fcb     $00,$00,$7C,$C6,$C6,$C6,$7E,$06,$06,$0C,$78,$00,$00
            fcb     $00,$00,$00,$18,$18,$00,$00,$00,$18,$18,$00,$00,$00
            fcb     $00,$00,$00,$18,$18,$00,$00,$00,$18,$18,$30,$00,$00
            fcb     $00,$00,$06,$0C,$18,$30,$60,$30,$18,$0C,$06,$00,$00
            fcb     $00,$00,$00,$00,$00,$7E,$00,$00,$7E,$00,$00,$00,$00
            fcb     $00,$00,$60,$30,$18,$0C,$06,$0C,$18,$30,$60,$00,$00
            fcb     $00,$00,$7C,$C6,$C6,$0C,$18,$18,$00,$18,$18,$00,$00
            fcb     $00,$00,$7C,$C6,$C6,$DE,$DE,$DE,$DC,$C0,$7C,$00,$00
            fcb     $00,$00,$10,$38,$6C,$C6,$C6,$FE,$C6,$C6,$C6,$00,$00
            fcb     $00,$00,$FC,$66,$66,$66,$7C,$66,$66,$66,$FC,$00,$00
            fcb     $00,$00,$3C,$66,$C2,$C0,$C0,$C0,$C2,$66,$3C,$00,$00
            fcb     $00,$00,$F8,$6C,$66,$66,$66,$66,$66,$6C,$F8,$00,$00
            fcb     $00,$00,$FE,$66,$62,$68,$78,$68,$62,$66,$FE,$00,$00
            fcb     $00,$00,$FE,$66,$62,$68,$78,$68,$60,$60,$F0,$00,$00
            fcb     $00,$00,$3C,$66,$C2,$C0,$C0,$DE,$C6,$66,$3A,$00,$00
            fcb     $00,$00,$C6,$C6,$C6,$C6,$FE,$C6,$C6,$C6,$C6,$00,$00
            fcb     $00,$00,$3C,$18,$18,$18,$18,$18,$18,$18,$3C,$00,$00
            fcb     $00,$00,$1E,$0C,$0C,$0C,$0C,$0C,$CC,$CC,$78,$00,$00
            fcb     $00,$00,$E6,$66,$6C,$6C,$78,$6C,$6C,$66,$E6,$00,$00
            fcb     $00,$00,$F0,$60,$60,$60,$60,$60,$62,$66,$FE,$00,$00
            fcb     $00,$00,$C6,$EE,$FE,$FE,$D6,$C6,$C6,$C6,$C6,$00,$00
            fcb     $00,$00,$C6,$E6,$F6,$FE,$DE,$CE,$C6,$C6,$C6,$00,$00
            fcb     $00,$00,$38,$6C,$C6,$C6,$C6,$C6,$C6,$6C,$38,$00,$00
            fcb     $00,$00,$FC,$66,$66,$66,$7C,$60,$60,$60,$F0,$00,$00
            fcb     $00,$00,$7C,$C6,$C6,$C6,$C6,$D6,$DE,$7C,$0C,$0E,$00
            fcb     $00,$00,$FC,$66,$66,$66,$7C,$6C,$66,$66,$E6,$00,$00
            fcb     $00,$00,$7C,$C6,$C6,$60,$38,$0C,$C6,$C6,$7C,$00,$00
            fcb     $00,$00,$7E,$7E,$5A,$18,$18,$18,$18,$18,$3C,$00,$00
            fcb     $00,$00,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$7C,$00,$00
            fcb     $00,$00,$C6,$C6,$C6,$C6,$C6,$C6,$6C,$38,$10,$00,$00
            fcb     $00,$00,$C6,$C6,$C6,$C6,$D6,$D6,$FE,$7C,$6C,$00,$00
            fcb     $00,$00,$C6,$C6,$6C,$38,$38,$38,$6C,$C6,$C6,$00,$00
            fcb     $00,$00,$66,$66,$66,$66,$3C,$18,$18,$18,$3C,$00,$00
            fcb     $00,$00,$FE,$C6,$8C,$18,$30,$60,$C2,$C6,$FE,$00,$00
            fcb     $00,$00,$3C,$30,$30,$30,$30,$30,$30,$30,$3C,$00,$00
            fcb     $00,$00,$80,$C0,$E0,$70,$38,$1C,$0E,$06,$02,$00,$00
            fcb     $00,$00,$3C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$3C,$00,$00
            fcb     $10,$38,$6C,$C6,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF
            fcb     $30,$30,$18,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$78,$0C,$7C,$CC,$CC,$76,$00,$00
            fcb     $00,$00,$E0,$60,$60,$78,$6C,$66,$66,$66,$7C,$00,$00
            fcb     $00,$00,$00,$00,$00,$7C,$C6,$C0,$C0,$C6,$7C,$00,$00
            fcb     $00,$00,$1C,$0C,$0C,$3C,$6C,$CC,$CC,$CC,$76,$00,$00
            fcb     $00,$00,$00,$00,$00,$7C,$C6,$FE,$C0,$C6,$7C,$00,$00
            fcb     $00,$00,$38,$6C,$64,$60,$F0,$60,$60,$60,$F0,$00,$00
            fcb     $00,$00,$00,$00,$00,$76,$CC,$CC,$CC,$7C,$0C,$CC,$78
            fcb     $00,$00,$E0,$60,$60,$6C,$76,$66,$66,$66,$E6,$00,$00
            fcb     $00,$00,$18,$18,$00,$38,$18,$18,$18,$18,$3C,$00,$00
            fcb     $00,$00,$06,$06,$00,$0E,$06,$06,$06,$06,$66,$66,$3C
            fcb     $00,$00,$E0,$60,$60,$66,$6C,$78,$6C,$66,$E6,$00,$00
            fcb     $00,$00,$38,$18,$18,$18,$18,$18,$18,$18,$3C,$00,$00
            fcb     $00,$00,$00,$00,$00,$EC,$FE,$D6,$D6,$D6,$C6,$00,$00
            fcb     $00,$00,$00,$00,$00,$DC,$66,$66,$66,$66,$66,$00,$00
            fcb     $00,$00,$00,$00,$00,$7C,$C6,$C6,$C6,$C6,$7C,$00,$00
            fcb     $00,$00,$00,$00,$00,$DC,$66,$66,$66,$7C,$60,$60,$F0
            fcb     $00,$00,$00,$00,$00,$76,$CC,$CC,$CC,$7C,$0C,$0C,$1E
            fcb     $00,$00,$00,$00,$00,$DC,$76,$66,$60,$60,$F0,$00,$00
            fcb     $00,$00,$00,$00,$00,$7C,$C6,$70,$1C,$C6,$7C,$00,$00
            fcb     $00,$00,$10,$30,$30,$FC,$30,$30,$30,$36,$1C,$00,$00
            fcb     $00,$00,$00,$00,$00,$CC,$CC,$CC,$CC,$CC,$76,$00,$00
            fcb     $00,$00,$00,$00,$00,$66,$66,$66,$66,$3C,$18,$00,$00
            fcb     $00,$00,$00,$00,$00,$C6,$C6,$D6,$D6,$FE,$6C,$00,$00
            fcb     $00,$00,$00,$00,$00,$C6,$6C,$38,$38,$6C,$C6,$00,$00
            fcb     $00,$00,$00,$00,$00,$C6,$C6,$C6,$C6,$7E,$06,$0C,$F8
            fcb     $00,$00,$00,$00,$00,$FE,$CC,$18,$30,$66,$FE,$00,$00
            fcb     $00,$00,$0E,$18,$18,$18,$70,$18,$18,$18,$0E,$00,$00
            fcb     $00,$00,$18,$18,$18,$18,$00,$18,$18,$18,$18,$00,$00
            fcb     $00,$00,$70,$18,$18,$18,$0E,$18,$18,$18,$70,$00,$00
            fcb     $00,$00,$76,$DC,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$10,$38,$6C,$C6,$C6,$FE,$00,$00,$00

