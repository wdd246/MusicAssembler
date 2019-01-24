;Dane w pliku txt
;Przykład: 1A0
;Pierwszy znak to numer oktawy od 1 do 7
;Drugi znak to nuta A-G całe tony (C-H), a od H-M poltony (Cis-Ais)
;Trzeci znak to dlugosc dzwieku od 0-4 (0=1/16,1=1/8,2=1/4,3=1/2,4=1)
;Na koniec piosenki dajemy '/'
;Pauze oznaczamy ';aX' - gdzie X to dlugośc 0-4 (jak wyżej). ';' ponieważ w kodzie ASCII ';'-'1' oznacza oktawe nr.11 czyli niesłyszalną. 
;---------------------------------------------------------
dane			segment
F				equ 	1193000 ;Fdz
				;------------
				;nuty
nuty			dw		(F/33) ;dzwiek C -> A				
				dw		(F/37) ;dzwiek D -> B				
				dw		(F/41) ;dzwiek E -> C				
				dw		(F/44) ;dzwiek F -> D				
				dw		(F/49) ;dzwiek G -> E
				dw		(F/55) ;dzwiek A -> F
				dw		(F/62) ;dzwiek H -> G
				;------------		
				dw		(F/35) ;dzwiek Cis	-> H
				dw		(F/39) ;dzwiek Dis	-> I
				dw		(F/42) ;dzwiek Eis	-> J
				dw		(F/46) ;dzwiek Fis	-> K
				dw		(F/52) ;dzwiek Gis	-> L
				dw		(F/58) ;dzwiek Ais	-> M
				;-------------
				;dlugosc dzwieku
dlu				dw 		1 			 ;1/16 = 67.5 ms
				dw		2 			 ;1/8 = 125ms
				dw 		4 			 ;1/4 = 250 ms
				dw		8 			 ;pol nuta = 500ms 
				dw		16			 ;cala nuta = 1s
				;------------
linijka			label                ;Dane z pliku - 5 B
oktawa			db		?            ;pytajnik oznacza wartość nieustaloną (można skojarzyć np. ze stworzeniem zmiennej w C++ i nie przypisaniem do niej wartości)
nuta			db		?
dlugosc			db		?			 ;Długość dzwieku
				dw		?            ;2 bajty = 0Dh, 0Ah = koniec linijki
nazwaplik		db		80h dup(0)   ;Rezerwujemy pamięć na nazwę pliku (80h bajtów o wartości 0 - rezerwujemy zerami gdyż nazwaplik pliku musi się kończyć bajtem 0)
napis 			db 		0ah,0dh,'Blad odczytu pliku',0ah,0dh,'$'	
dane			ends
;---------------------------------------------------------
stoss			segment
				dw		100h dup(0)
top				Label word
stoss			ends
;---------------------------------------------------------
prog			segment
				assume	cs:prog, ds:dane, ss:stoss

start:			mov		ax,dane
				mov		ds,ax
				mov		ax,stoss
				mov		ss,ax
				mov		sp,offset top
				;---------------------------------------------------------
				;PSP -> ES
				mov		cl,es:[80h] ;Pod adresem 80h w PSP przechowywana jest długość stringa z argumentami. 81h dane z PSP ale strign od 82h bo spacja
				dec		cl ;Długośc -1
				mov		si,offset nazwaplik
				mov		di,82h ;Początek stringa z argumentami w PSP bez spacji
				;---------------------------------------------------------
				;Nazwa pliku z PSP do s.danych
parametr: 		mov		al,es:[di] ; Dostajemy dane do ES
				mov		ds:[si],al ;Skopiuj z AL do DS:SI -> nazwapliku
				inc		si
				inc		di
				dec		cl ;nazwa-- = dlugosc--
				jnz		parametr ;jeżeli dl!=0 to jeszcze raz
				;---------------------------------------------------------
				;Otwieranie pliku
				mov		ax,3D00h ;otwarcie pliku
				mov		dx,offset nazwaplik ;nazwa pliku
				int		21h
				jc		blad ;c=1 -> bład
				mov		bx,ax ;ID pliku
				;---------------------------------------------------------
pobierz:		;Pobieranie danych z pliku
				mov		ah,3Fh ;pobieranie z pliku z BX, CX - ilośc bajtów do odczytu. DS:DX -> Bufor na dane
				mov		cx,5 ;Ilość bajtów do pobrania. Oktwa, nuta i dlugosc + 2 bajty końca lini
				mov		dx,offset linijka ;Miejsce na dane z pliku
				int		21h
				jc		blad ;c=1 -> błąd
				cmp		ax,cx ;AX<- ilośc aktulanie pobranych plików
				jnz		koniec ;ax!=cx to koniec bo pobrało inną liczbę bajtów
				cmp 	dx,'/'
				je 		koniec ;na końcu pliku jest '/'
				;---------------------------------------------------------
				;Nuta i oktawa
				xor		ah,ah 
				mov		cl,oktawa ;Pierwszy symbol z linijki to okatawa
				sub		cl,'1' ;'x'-'1'= liczba (int) o jaką nam chodzi oktawe. 1-7
				
				mov		al,nuta ;Drugi symbol z linijki to nut
				sub		al,'A' ;'N'-'A' = liczba (int) o jaką nam chodzi. A-M
				mov		si,ax ;int to nasz wskaźnik po tablicy z nutami
				shl		si,1 ;Przesuwamy w lewo na 2B bo w tablicy z nutami mamy dw czyli 2B
				add		si,offset nuty ;Dodajemy adres pierwszej nuty by otrzymać wskaźnik na nutę która nas interesuje
				mov		ax,ds:[si] ;Pobieramy tą nutę z segmentu danych do AX
				
				shr		ax,cl ;Przesuwamy w prawo o tą wartość (dzielimy przez 2 i potęgi oktawy). (1193000/33)/2^oktawa(cl) 0-7
				
				out		42h,al ;Wrzucamy część mniejszą rejestru AX do portu 42h
				mov		al,ah ;out nie może pobierać wartości z AH
				out		42h,al ;A następnie wrzucamy część większą rejestru AX do portu 42h
				;---------------------------------------------------------
				;Głośnik ON
				in		al,61h ;Port 61h, port B 8255 od 60h.
				or		al,00000011b ;2 pierwsze bity ustawiamy na 1. B0 i B1
				out		61h,al ;B0 i B1 do 8255
				;---------------------------------------------------------
				;Czas
				push	bx ;zapis ID pliku
				xor		bx,bx 
				xor		dx,dx
				xor 	cx,cx
				mov		cl,dlugosc ;Trzeci symbol z linijki to dlugość i 2 bajty końca lini. Ale zapsijemy do cl czyli 1 bajt sama dlugosc
				sub		cl,'0' ;'x'-'0'= liczba (int) o jaką nam chodzi dlugość. 0-4
				xor 	ch,ch
				mov		di,cx ;int dlugosci jest wskaźnikiem
				shl		di,1 ;Przesuwamy w lewo na 2B bo w tablicy z dlu mamy dw czyli 2B
				add		di,offset dlu ;Dodajemy adres pierwszej dlugosci by otrzymać wskaźnik na dlugosc która nas interesuje
				mov		cx,ds:[di] ;pobieramy dlugosc
				xor 	dx,dx
				
				mov		ah,86h ;Czas. CX<- czas czyli dlugosc. 1/16 to ok.18x na sek. 
				int		15h
				
				pop		bx
				jmp		pobierz; idziemy do kolejnej linijki
				;---------------------------------------------------------
koniec:			;Wyłączenie głośnika
				in		al,61h ;Pobieramy wartość do AL z portu 61h
				and		al,11111100b ;Zerujemy bity B0 i B1 z 8255
				out		61h,al ;aktualizucjemy porty
				
				mov		ah,3Eh ;Zamknięcie pliku oznaczonego ID BX
				int		21h
				mov     ah,4ch ;Funkcja kończąca pracę programu
				mov	    al,0
				int	    21h
				
blad:			mov 	ah,09h
				mov 	dx,offset napis
				int 	21h
				jmp 	koniec
prog			ends
end start