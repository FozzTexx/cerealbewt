10 DIM RATE(14)
20 REM Select the data port
30 PRINT CHR$(27)+"E"; : REM Clear the screen
40 PRINT : PRINT : PRINT : PRINT
50 PRINT "The serial ports are:" : PRINT
60 PRINT ,"          A - Serial Port TTY - left hand on back"
70 PRINT ,"          B - Serial Port UL1 - right hand on back"
80 PRINT : PRINT
90 PRINT ,"Select the port you want to use, A or B ";
100 PORT$ = INPUT$(1)
110 PRINT PORT$
120 IF PORT$ = “a" THEN STATIO=2 : DATIO=0 : GOTO 210
130 IF PORT$ = "A" THEN STATIO=2 : DATIO=0 : GOTO 210
140 IF PORT$ = "b" THEN STATIO=3 : DATIO=1 : GOTO 210
150 IF PORT$ = "B" THEN STATIO=3 : DATIO=1 : GOTO 210
160 GOTO 30

200 REM Set the baud rate
210 PRINT CHR$(27)+"E"; : REM Clear the screen
220 PRINT : PRINT : PRINT : PRINT
230 PRINT "The available baud rates are as follows:"-: PRINT
240 PRINT ," 1 =     300 baud"
250 PRINT ," 2 =     600 baud"
260 PRINT ," 3 =    1200 baud"
270 PRINT ," 4 =    2400 baud"
280 PRINT ," 5 =    4800 baud"
290 PRINT ," 6 =    9600 baud"
300 PRINT ," 7 =   19200 baud"
310 PRINT : PRINT : PRINT
320 PRINT "Select one of the above baud rates: ";
330 RATE$ = INPUT$(1)
340 IF RATE$ > "7" THEN 210
350 IF RATE$ < "1" THEN 210
360 PRINT RATE$

370 INPUT "File to save as";F$
380 OPEN "O",#1,F$

400 REM Now set the baud rate in the port selected
410 DEF SEG = &HE002
420 IF DATIO = 0 THEN POKE 3,54 : IF DATIO = 1 THEN POKE 3,118
430 FOR I = 1 TO 14
440 READ RATE(I) : REM Set the baud rate matrix
450 NEXT I
460 NODE = (VAL(RATE$)-1)*2+1
470 POKE DATIO,RATE(NODE)
480 POKE DATIO,RATE(NODE+1)

500 REM Receive data
510 DEF SEG = &HE004
520 TEXT$="READY"
530 GOSUB 650:TEXT$=MID$(TEXT$,1):IF LEN(TEXT$) THEN 530

540 GOSUB 800: REM Read length of file in decimal
550 GOSUB 900: REM Read hex value of byte
560 PRINT#1,CHR$(BYTE);
570 IVAL = IVAL - 1
580 IF IVAL > 0 THEN GOTO 550
590 CLOSE #1

649 END

650 STATUS=PEEK(STATIO) : STATUS=STATUS AND 4
660 IF STATUS = 0 THEN 650 :REM Waiting to send char
670 POKE DATIO, ASC(TEXT$)
680 RETURN

690 STATUS = PEEK(STATIO) :STATUS STATUS AND 1
700 IF STATUS = 0 THEN 690
710 DATUM = PEEK(DATIO) AND 127
720 POKE DATIO,DATUM
730 RETURN

800 REM Read integer value
810 TEXT$ = ""
820 GOSUB 690
830 IF DATUM = 13 THEN IVAL = VAL(TEXT$):RETURN
840 TEXT$ = TEXT$ + CHR$(DATUM)
850 GOTO 820

900 REM Read two digit hex value
910 HX$ = ""
920 GOSUB 690
930 HX$ = HX$ + CHR$(DATUM)
940 IF LEN(HX$) < 2 THEN 920
950 GOSUB 1000: BYTE = NIB * 16
960 HX$ = MID$(HX$,2):GOSUB 1000 : BYTE = BYTE + NIB
970 RETURN

1000 NIB = ASC(HX$) - 48
1010 IF NIB > 9 THEN NIB = NIB - 7
1020 IF NIB > 15 THEN NIB = NIB - 32
1030 RETURN

2000 DATA 0,1,&H80,0,&H40,0,&H20,0,&H10,0,8,0,4,0
