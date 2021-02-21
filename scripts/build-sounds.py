#!/usr/bin/env python3
#********************************************************************************
# DynoSprite - scripts/build-sounds.py
# Copyright (c) 2014, Richard Goedeken
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

import os
import sys
from compression import *

#******************************************************************************
# main function for standard script execution
#

if __name__ == "__main__":
    print("DynoSprite Sound Builder script")
    # get input paths
    if len(sys.argv) != 4:
        print(f"****Usage: {sys.argv[0]} <in_raw_folder> <out_cc3_folder> <out_asm_folder>")
        sys.exit(1)
    rawdir = sys.argv[1]
    cc3dir = sys.argv[2]
    asmdir = sys.argv[3]
    # make list of raw sound data files found
    filelist = os.listdir(rawdir)
    soundRawFiles = [name for name in filelist if len(name) >= 11 and name[:5] == "sound" and name[5:7].isdigit() and name[-4:].lower() == ".raw"]
    soundRawFiles.sort()
    soundRawNumbers = [int(name[5:7]) for name in soundRawFiles]
    numSounds = len(soundRawFiles)
    minNumber = min(soundRawNumbers)
    maxNumber = max(soundRawNumbers)
    print(f"    Found {int(numSounds)} sound files, numbered from {int(minNumber)} to {int(maxNumber)}")
    # read raw sound data files and compress them
    allCompSoundData = b''
    allSoundSizes = [ ]
    for i in range(maxNumber+1):
        if i not in soundRawNumbers:
            allSoundSizes.append((0, 0))
            continue
        idx = soundRawNumbers.index(i)
        rawSoundData = open(os.path.join(rawdir, soundRawFiles[idx]), "rb").read()
        rawLength = len(rawSoundData)
        rawPadding = rawLength & 255
        if rawPadding > 0:
            rawPadding = 256 - rawPadding
        rawSoundData += bytes((0x80,)) * rawPadding
        comp = Compressor(rawSoundData)
        compSoundData = comp.Deflate(bPrintInfo=False, bUseGzip=True)
        allCompSoundData += compSoundData
        allSoundSizes.append((len(rawSoundData), len(compSoundData)))
    # write out the data file
    f = open(os.path.join(cc3dir, "SOUNDS.DAT"), "wb")
    f.write(allCompSoundData)
    f.close()
    # write sound directory table to include in DynoSprite core
    f = open(os.path.join(asmdir, "gamedir-sounds.asm"), "w")
    f.write("Gamedir_Sounds\n")
    s = str(maxNumber+1)
    f.write((" " * 24) + "fcb     " + s + (" " * (16 - len(s))) + "* number of sound waveforms\n")
    for i in range(maxNumber+1):
        if i not in soundRawNumbers:
            f.write((" " * 24) + f"* Waveform: {int(i):02} - [empty]\n")
            f.write((" " * 24) + "fdb     " + "0,0\n")
            continue
        idx = soundRawNumbers.index(i)
        f.write((" " * 24) + f"* Waveform: {int(i):02} - {soundRawFiles[idx][8:-4]}\n")
        s = str(allSoundSizes[i][0])
        f.write((" " * 24) + "fdb     " + s + (" " * (16-len(s))) + "* Uncompressed size (bytes) of waveform\n")
        s = str(allSoundSizes[i][1])
        f.write((" " * 24) + "fdb     " + s + (" " * (16-len(s))) + "* Compressed size / Starting address\n")
    f.close()

