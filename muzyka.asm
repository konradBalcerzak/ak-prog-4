prog segment
assume  cs:prog, ds:dane, ss:stosik
start:      MOV     ax,dane
            MOV     ds,ax
            MOV     ax,stosik
            MOV     ss,ax
            MOV     sp,offset szczyt
musicStart: CALL    getFile
            CALL    openFile
            MOV     ax,fileHandle
            CMP     ax,5
            JL      noFileErr
            CALL    playNotes
musicEnd:   MOV     ah,4ch
            MOV     al,0
            INT     21h
noFileErr:  MOV     ah,09h
            MOV     dx,offset errNoFile
            INT     21h
            JMP     musicEnd
noArgERR:   POP     ds
            MOV     ah,09h
            MOV     dx,offset errNoArg
            INT     21h
            JMP     musicEnd
getFile:    PUSH    es
            PUSH    ds
            POP     es
            MOV     ah,62h
            INT     21h
            MOV     pspSeg,bx
            PUSH    ds
            MOV     ds,pspSeg
            MOV     si,80h
            XOR     ch,ch
            MOV     cl,[si]
			CMP     cl,0
			JE		noArgERR
            DEC     cl
            POP     ds
            MOV     argLen,cl
            PUSH    ds
            MOV     ds,bx
            MOV     si,82h
            MOV     di,offset fileName
            REP     MOVSB
            POP     ds
            POP     es
            MOV     fileName[di],00h
            RET
openFile:   MOV     ax,3D00h
            MOV     dx,offset fileName
            STC
            CMC
            INT     21h
            MOV     fileHandle,ax
            RET
playNotes:  MOV     ah,3fh
            MOV     bx,fileHandle
            MOV     cx,5
            MOV     dx,offset fileReadBuf
            INT     21h
            CMP     ax,cx
            JNE     songEnd
            CALL    getNote
            CALL    getOctave
            CALL    getLength
            XOR     ch,ch
            MOV     cl,7
            SUB     cl,currOct
            MOV     ax,currNote
            CMP     ax,1
            JE      sendNote
            SHL     ax,cl
            MOV     currNote,ax
sendNote:   OUT     42h,al
            MOV     al,ah
            OUT     42h,al
            IN      al,61h
            OR      al,00000011b
            OUT     61h,al
            MOV     cx,currLength
waitLoop:   PUSH    cx
            CALL    waitSec
            POP     cx
            LOOP    waitLoop
            IN      al,61h
            AND     al,11111100b
            OUT     61h,al
            JMP     playNotes
songEnd:    RET
waitSec:    MOV     ah,86h
            MOV     dx,0FFFFh
            XOR     cx,cx
            INT     15h
            RET
getNote:    MOV     dx,noteS
            MOV     al,fileReadBuf[0]
            ;validate(non allowed symbol will be pause)
validateN:  SUB     al,'A'
			CMP     al,32
            JB      chooseN
			SUB     al,32
			JMP     chooseHN
            ;note
chooseN:    CMP     al,6
			JG      noteRet
			MOV     bx,offset note
            JMP     selectNote
           ;halfnote
chooseHN:   CMP     al,6
			JG      noteRet
			MOV     bx,offset halfNote
            JMP     selectNote
           ;note selection
selectNote: XOR     ah,ah
			;if you use si program breaks for some reason
			MOV     cl,2
			MUL     cl
            MOV     di,ax
            MOV     dx,[bx][di]
noteRet:    MOV     currNote,dx
            RET
getOctave:  MOV     al,fileReadBuf[1]
            SUB     al,'0'
            MOV     currOct,al
            RET
getLength:  MOV     al,fileReadBuf[2]
            CMP     al,'S'
            JNE     cmpQuarter
            MOV     dx,lenS
            JMP     lenRet
cmpQuarter: CMP     al,'Q'
            JNE     cmpHalf
            MOV     dx,lenQ
            JMP     lenRet
cmpHalf:    CMP     al,'H'
            JNE     cmpFull
            MOV     dx,lenH
            JMP     lenRet
cmpFull:    CMP     al,'F'
            JNE     lenRet
            MOV     dx,lenF
            JMP     lenRet
lenRet:     MOV     currlength,dx
            RET
prog ends


dane segment
note  		dw 338,301,570,507,452,427,380
halfNote    dw 319,1,538,479,439,403,359
noteS       dw 1
pspSeg      dw ?
argLen      db ?
fileName    db 127 dup(?)
fileHandle  dw ?
fileReadBuf db 5 dup(?)

currSymbol  db ?
currOct     db ?
currlength  dw ?
currNote    dw ?
            dw 0



lenS        dw 1
lenQ        dw 2
lenH        dw 4
lenF        dw 16

errNoFile   db "Nie znaleziono pliku",13,10,'$'
errNoArg    db "Program wymaga podania nazwy pliku w argumencie",13,10,'$'

dane ends

stosik segment
            dw 100h dup(0)
            szczyt Label word
stosik ends

end start