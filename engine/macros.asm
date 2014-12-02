*********************************************************************************
* DynoSprite - macros.asm
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

 IFEQ CPU-6309

* define macros for operations using 6309 instructions
ADD_D_TO_X MACRO
            addr        d,x
 ENDM
ADD_D_TO_Y MACRO
            addr        d,y
 ENDM
ADD_D_TO_U MACRO
            addr        d,u
 ENDM
DECREMENT_D MACRO
            decd
 ENDM
INCREMENT_D MACRO
            incd
 ENDM
NEGATE_D MACRO
            negd
 ENDM
 ELSE

* define macros for operations using 6809 instructions
ADD_D_TO_X MACRO
            leax        d,x
 ENDM
ADD_D_TO_Y MACRO
            leay        d,y
 ENDM
ADD_D_TO_U MACRO
            leau        d,u
 ENDM
DECREMENT_D MACRO
            subd        #1
 ENDM
INCREMENT_D MACRO
            addd        #1
 ENDM
NEGATE_D MACRO
            negb
            adca        #0
            nega
 ENDM

 ENDC
