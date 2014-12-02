#!/usr/bin/env python
#********************************************************************************
# DynoSprite - scripts/build-readme.py
# Copyright (c) 2013-2014, Richard Goedeken
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#********************************************************************************

import sys

""" Scroll.asm:
ScrollDown                            * USR0
            ldx         #$420
!           ldd         ,x++
            std         -34,x
            cmpx        #$5E0
            bne         <
            rts

ScrollUp                              * USR1
            ldx         #$5E0
!           ldd         -34,x
            std         ,--x
            cmpx        #$420
            bne         <
            rts

TestKeys                              * USR2
            clra
            ldb         #$EF
            stb         $FF02
            ldb         $FF00
            andb        #$08
            bne         >
            ldb         #1              * 1 = up
            bra         FoundKey
!           ldb         #$F7
            stb         $FF02
            ldb         $FF00
            andb        #$08
            bne         >
            ldb         #2              * 2 = down
            bra         FoundKey
!           clrb
FoundKey
            jmp         >$B4F4          * GIVABF: return value in D
"""

BASICPROG = """
5 CLEAR 6400,30000: ON BRK GOTO 99
10 A=30000:READ N1:FOR X = 0 TO N1-1:READ B:POKE A+X,B:NEXT:DEFUSR0=A
12 A=A+N1:READ N2:FOR X = 0 TO N2-1:READ B:POKE A+X,B:NEXT:DEFUSR1=A
14 A=A+N2:READ N3:FOR X = 0 TO N3-1:READ B:POKE A+X,B:NEXT:DEFUSR2=A
20 DIM L$(#NUMLINES):FOR I=1 TO #NUMLINES: READ L$(I):NEXT
30 SL=1
40 FOR I=SL TO SL+14:PRINT @((I-SL)*32),L$(I);:NEXT
50 PRINT "arrow:MOVE break:QUIT enter:RUN";
60 I=USR2(0):IF I=2 AND SL > 1 THEN GOTO 62 ELSE IF I=1 AND SL < #NUMLINES-14 THEN GOTO 64 ELSE IF INKEY$=CHR$(13) THEN GOTO 66 ELSE GOTO 60
62 SL=SL-1:A=USR1(0):PRINT @0,L$(SL);:GOTO 60
64 SL=SL+1:A=USR0(0):PRINT @448,L$(SL+14);:GOTO 60
66 CLS:PRINT "LOADING...":LOADM"DYNO"
90 DATA 14,&H8E,&H04,&H20,&HEC,&H81,&HED,&H88,&HDE,&H8C,&H05,&HE0,&H26,&HF6,&H39
92 DATA 14,&H8E,&H05,&HE0,&HEC,&H88,&HDE,&HED,&H83,&H8C,&H04,&H20,&H26,&HF6,&H39
94 DATA 37,&H4F,&HC6,&HEF,&HF7,&HFF,&H02,&HF6,&HFF,&H00,&HC4,&H08,&H26,&H04,&HC6,&H01,&H20,&H11,&HC6,&HF7,&HF7,&HFF,&H02,&HF6,&HFF,&H00,&HC4,&H08,&H26,&H04,&HC6,&H02,&H20,&H01,&H5F,&H7E,&HB4,&HF4
99 CLS:END
"""

def GenerateReadme(textin, basout):
    # read the input text file
    inLines = open(textin, "r").read().split("\n")
    if inLines[-1] == "":
        inLines = inLines[:-1]
    # generate the output data lines
    outLines = [ ]
    ListMode = False
    for line in inLines:
        if len(line) == 0:
            outLines.append(" " * 32)
            ListMode = False
            continue
        if len(line) > 3 and line[0] == '{' and line[2] == '}':
            padchar = line[1]
            line = line[3:]
            numpad = 32 - len(line)
            halfpad = numpad / 2
            outLines.append((padchar * halfpad) + line.upper() + (padchar * (numpad-halfpad)))
            ListMode = False
            continue
        curLine = ""
        for word in line.split(" "):
            word = word.upper()
            if curLine == "":
                if ListMode == True and word[0] != '*':
                    word = "  " + word
                elif word[0] == '*':
                    ListMode = True
            if len(curLine) + len(word) == 32:
                outLines.append(curLine + word)
                curLine = ""
                continue
            if len(curLine) + len(word) < 32:
                curLine += word + " "
                continue
            outLines.append(curLine + " " * (32 - len(curLine)))
            if ListMode == True and word[0] != '*':
                curLine = "  " + word + " "
            else:
                curLine = word + " "
        if len(curLine) > 0:
            outLines.append(curLine + " " * (32 - len(curLine)))
    # write the output basic program
    f = open(basout, "w")
    f.write(chr(13))
    #f.write(BASICPROG)
    f.write(BASICPROG.replace("\n","\r").replace("#NUMLINES",str(len(outLines))))
    for idx in range(len(outLines)):
        #f.write('%i DATA "%s"\n' % (100 + idx * 10, outLines[idx]))
        f.write('%i DATA "%s"\r' % (100 + idx * 10, outLines[idx]))
    f.close()

#******************************************************************************
# main function call for standard script execution
#

if __name__ == "__main__":
    print "DynoSprite README.BAS Builder script"
    # get input paths
    if len(sys.argv) != 3:
        print "****Usage: %s <in_readme_text> <out_readme_bas>" % sys.argv[0]
        sys.exit(1)
    textin = sys.argv[1]
    basout = sys.argv[2]
    GenerateReadme(textin, basout)

