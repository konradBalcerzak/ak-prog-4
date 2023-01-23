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
            CALL    playNotes
            ;konczy dzialanie programu
musicEnd:   MOV     ah,4ch
            MOV     al,0
            INT     21h
            ;blad gdy wybrany plik nie istnieje
noFileErr:  MOV     ah,09h
            MOV     dx,offset errNoFile
            INT     21h
            JMP     musicEnd
            ;blad gdy nie podano argumentu przy wowolaniu programu
noArgERR:   POP     ds
            MOV     ah,09h
            MOV     dx,offset errNoArg
            INT     21h
            JMP     musicEnd
            ;pobranie nazwy pliku
genericERR: MOV     ah,09h
            MOV     dx,offset errGeneric
            INT     21h
            JMP musicEnd
            ;STACK  es->ds, ds->ds, ds->ds, es->es
getFile:    PUSH    es
            PUSH    ds
            POP     es
            ;pobranie adresu psp ktory zawiera dane o wywolanym programie (w bx)
            MOV     ah,62h
            INT     21h
            MOV     pspSeg,bx
            PUSH    ds
            MOV     ds,pspSeg
            ;na ofset 80 w pspSeg jest ilosc znakow ktore uzytkownik wpisal po wywolaniu programu(jako argument)
            MOV     si,80h
            XOR     ch,ch
            MOV     cl,[si]
            CMP     cl,0
            JE      noArgERR
            ;dekrementujemy cl bo nie czytamy pierwszego znaku(spacji)
            DEC     cl
            MOV     ds,bx
            ;zapisujemy argument do zmiennej
            MOV     si,82h
            MOV     di,offset fileName
            REP     MOVSB
            POP     ds
            POP     es
            ;ciag musi byc konczony bajtem 0
            MOV     fileName[di],00h
            RET
            ;otwiera plik
openFile:   MOV     ax,3D00h ;al = 00h tylko do odczytu
            MOV     dx,offset fileName
            ;w fladze CF bedzie czy poprawnie otwarto plik
            CLC
            INT     21h
            ;CF = 1 - blad
            JC      noFileErr
            MOV     fileHandle,ax
            RET
            ;procedura grajaca muzyke
playNotes:  MOV     ah,3fh
            MOV     bx,fileHandle
            ;ilosc bajtow do odczytania
            MOV     cx,5
            ;gdzie bajty zostana zapisane
            MOV     dx,offset fileReadBuf
            CLC
            INT     21h
            ;CY = 1 - blad
            JC      genericERR
            ;czy przeczytano dokladnie 5 znakow (3 znaki dzwieku, i enter 10,13), jesli nie to uznajemy za koniec piosenki
            CMP     ax,cx
            JNE     songEnd
            ;wyczytuje podzielnik nuty
            CALL    getNote
            ;wyczytuje oktawe
            CALL    getOctave
            ;wyczytuje dlugosc trwania nuty(w 1/16 sekundy)
            CALL    getLength
            XOR     ch,ch
            ;konwersja nuty z oktawy 8 na wybrana oktawe ze wzoru 2^(7 - currOct) * podzielnik nuty(z currNote)
            MOV     cl,7
            SUB     cl,currOct
            MOV     ax,currNote
            CMP     ax,1
            JE      sendNote
            ;przesuniecie logiczne w lewo cl razy(mnozenie razy 2^cl)
            SHL     ax,cl
            MOV     currNote,ax
sendNote:   ;wyslanie nuty do timera w trybie pracy L2 (najpierw mlodszy potem starszy bajt)
            OUT     42h,al
            MOV     al,ah
            OUT     42h,al
            ;uruchomienie glosnika (ustawienie 2 ostatnich bajtow na 1 bez edycji reszty)
            IN      al,61h
            OR      al,00000011b
            OUT     61h,al
            ;odczekanie czasu trwania nuty
            MOV     cx,currLength
waitLoop:   PUSH    cx
            CALL    waitSec
            POP     cx
            LOOP    waitLoop
            ;wylaczenie glosnika (ustawienie 2 ostatnich bajtow na 0 bez edycji reszty)
            IN      al,61h
            AND     al,11111100b
            OUT     61h,al
            ;jesli podczas trwania muzyki wcisniemy klawisz, konczymy dzialanie programu
            MOV     ah,01h
            INT     16h
            ;flaga ZF = 1, wcisnieto klawisz
            JZ      playNotes
            JMP     musicEnd
songEnd:    RET
            ;czeka 1/16 sekundy
waitSec:    MOV     ah,86h
            MOV     dx,0FFFFh
            XOR     cx,cx
            INT     15h
            RET
getNote:    MOV     dx,halfNote[2]; domyslna wartosc podzielnika nuty = 1(pauza)
            MOV     al,fileReadBuf[0]; pierwszy wyczytany znak
validateN:  SUB     al,'A'
            ; czy jest cala nuta ('A'>=al>='a')
            CMP     al,20h
            JB      chooseN
            ; jest pol nuta (al>='a') odejmujemy 32 aby znak 'a' stal sie wartoscia 0
            SUB     al,20h
            JMP     chooseHN
            ; cala nuta
chooseN:    CMP     al,6 ;sprawdzamy czy al>='G'
            JG      noteRet ;poza zakresem, pobierz domyslna nute
            MOV     bx,offset note ; ustawiamy zrodlo wartosci nut
            JMP     selectNote
           ; pol nuta (nuta bis nie istnieje wiec zastepujemy ja pauza)
chooseHN:   CMP     al,6 ;sprawdzamy cz al>='g'
            JG      noteRet
            MOV     bx,offset halfNote
            JMP     selectNote
           ; wybor nuty ze zrodla. w al jest indeks oznaczajacy nute
selectNote: XOR     ah,ah
           ;mnozymy indeks razy 2 poniewaz wartosci sa zapisane w slowach 2 bitowych
            MOV     cl,2
            MUL     cl
            MOV     di,ax
            MOV     dx,[bx][di]
noteRet:    MOV     currNote,dx
            RET
getOctave:  MOV     cl,4;domyslna wartosc oktawy
            MOV     al,fileReadBuf[1] ;drugi wczytany znak
            SUB     al,'0'
            ;walidacja oktawy (miedzy 1 i 7)
            CMP     al,1
            JB      octRet
            CMP     al,7
            JG      octRet
            MOV     cl,al
octRet:     MOV     currOct,cl
            RET
getLength:  MOV     al,fileReadBuf[2] ;trzeci wyczytany znak
            XOR     dh,dh
            MOV     dl,lenDefault ;domyslna dlugosc trwania nuty
            ;dlugosc nuty powinna byc zapisana w notacji szesznatkowej
            CMP     al,'0'
            JL      lenRet
            CMP     al,'9'
            JLE     lenDec
            CMP     al,'A'
            JL      lenRet
            CMP     al,'F'
            JLE     lenHex
            JMP     lenRet
            ; konwersja znakow '0'-'9' do liczb 0-9
lenDec:     SUB     al,'0'
            MOV     dl,al
            JMP     lenRet
            ; konwersja znakow 'A'-'F' do liczb 10-16
lenHex:     SUB     al,55 ;65 to znak 'A' w kodzie ascii a chcemy zeby 'A'=10
            MOV     dl,al
lenRet:     MOV     currlength,dx
            RET
prog ends


dane segment
note        dw 338,301,570,507,452,427,380 ;podzielniki nut
halfNote    dw 319,1,538,479,439,403,359 ; podzielniki pol nut, nie ma polnuty bis wiec ustalamy ze jest ona pauza
lenDefault  db 4 ;domyslna dlugosc trwania nuty
pspSeg      dw ?
fileName    db 127 dup(?)
            dw 0
fileHandle  dw ?
fileReadBuf db 5 dup(?)

currOct     db ?
currlength  dw ?
currNote    dw ?
            dw 0




errNoFile   db "Nie znaleziono pliku",13,10,'$'
errNoArg    db "Program wymaga podania nazwy pliku w argumencie",13,10,'$'
errGeneric  db "Podczas odczytywania pliku nastapil blad",10,13,'$'

dane ends

stosik segment
            dw 100h dup(0)
            szczyt Label word
stosik ends

end start