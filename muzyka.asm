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
            ;CALL    moveCursor
            JMP     playNotes
songEnd:    RET
waitSec:    MOV     ah,86h
            MOV     dx,0FFFFh
            XOR     cx,cx
            INT     15h
            RET
moveCursor: XOR     cx,cx
            MOV     dx,5
            MOV     ax,4201h
            MOV     bx,fileHandle
            INT     21h
            RET
getNote:    MOV     dx,noteS
            MOV     al,fileReadBuf[0]
            CMP     al,'C'
            JNE     cmpCis
            MOV     dx,noteC
            JMP     noteRet
cmpCis:     CMP     al,'c'
            JNE     cmpD
            MOV     dx,noteCs
            JMP     noteRet
cmpD:       CMP     al,'D'
            JNE     cmpDis
            MOV     dx,noteD
            JMP     noteRet
cmpDis:     CMP     al,'d'
            JNE     cmpE
            MOV     dx,noteDs
            JMP     noteRet
cmpE:       CMP     al,'E'
            JNE     cmpEis
            MOV     dx,noteE
            JMP     noteRet
cmpEis:     CMP     al,'e'
            JNE     cmpF
            MOV     dx,noteEs
            JMP     noteRet
cmpF:       CMP     al,'F'
            JNE     cmpFis
            MOV     dx,noteF
            JMP     noteRet
cmpFis:     CMP     al,'f'
            JNE     cmpG
            MOV     dx,noteFs
            JMP     noteRet
cmpG:       CMP     al,'G'
            JNE     cmpGis
            MOV     dx,noteG
            JMP     noteRet
cmpGis:     CMP     al,'g'
            JNE     cmpA
            MOV     dx,noteGs
            JMP     noteRet
cmpA:       CMP     al,'A'
            JNE     cmpAis
            MOV     dx,noteA
            JMP     noteRet
cmpAis:     CMP     al,'a'
            JNE     cmpB
            MOV     dx,noteAs
            JMP     noteRet
cmpB:       CMP     al,'B'
            JNE     noteRet
            MOV     dx,noteB
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

pspSeg      dw ?
argLen      db ?
fileName    db 127 dup(?)
fileHandle  dw ?
fileReadBuf db 5 dup(?)

currSymbol  db ?
currOct     db ?
currlength  dw ?
currNote    dw ?

noteC       dw 570
noteCs      dw 538
noteD       dw 507
noteDs      dw 479
noteE       dw 452
noteEs      dw 439
noteF       dw 427
noteFs      dw 403
noteG       dw 380
noteGs      dw 359
noteA       dw 338
noteAs      dw 319
noteB       dw 301
noteS       dw 1

lenS        dw 1
lenQ        dw 2
lenH        dw 4
lenF        dw 16

errNoFile   db "Nie znaleziono pliku",13,10,'$'

dane ends

stosik segment
            dw 100h dup(0)
            szczyt Label word
stosik ends

end start