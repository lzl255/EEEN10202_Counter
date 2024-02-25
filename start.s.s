processor 18F8722
radix   dec
    
CONFIG  OSC = HS  ; use the high speed external crystal on the PCB
CONFIG  WDT = OFF ; turn off the watchdog timer
CONFIG  LVP = OFF ; turn off low voltage mode

#include <xc.inc>

DIGIT0 equ 0b10000100
DIGIT1 equ 0b11110101
DIGIT2 equ 0b01001100
DIGIT3 equ 0b01100100
DIGIT4 equ 0b00110101
DIGIT5 equ 0b00100110
DIGIT6 equ 6 ; happy coincidence
DIGIT7 equ 0b11110100
DIGIT8 equ 0b00000100
DIGIT9 equ 0b00100100

DIGIT0_DOT equ 0b10000000
DIGIT1_DOT equ 0b11110001
DIGIT2_DOT equ 0b01001000
DIGIT3_DOT equ 0b01100000
DIGIT4_DOT equ 0b00110001
DIGIT5_DOT equ 0b00100010
DIGIT6_DOT equ 0b00000010
DIGIT7_DOT equ 0b11110000
DIGIT8_DOT equ 0b00000000
DIGIT9_DOT equ 0b00100000

LEFT_PB_PRESSED	    equ 0b00000001
RIGHT_PB_PRESSED    equ 0b00100000

; Variables
ARR_DIGITS		equ 0x200	; 0x200 ~ 0x209
DELAY_COUNTER		equ 0x210
SUPER_DELAY_COUNTER	equ 0x211
LEFT_DIGIT		equ 0x212
RIGHT_DIGIT		equ 0x213
LEFT_PB_PREV		equ 0x214
LEFT_PB_NOW		equ 0x215
RIGHT_PB_PREV		equ 0x216
RIGHT_PB_NOW		equ 0x217
SWITCHES_PREV		equ 0x218
SWITCHES_NOW		equ 0x219

PSECT resetVector, class=CODE, reloc=2
resetVector:
    goto start

PSECT start, class=CODE, reloc=2

init_digits_arr MACRO
	movlw	DIGIT0
	movwf	ARR_DIGITS+0, a
	movlw	DIGIT1
	movwf	ARR_DIGITS+1, a
	movlw	DIGIT2
	movwf	ARR_DIGITS+2, a
	movlw	DIGIT3
	movwf	ARR_DIGITS+3, a
	movlw	DIGIT4
	movwf	ARR_DIGITS+4, a
	movlw	DIGIT5
	movwf	ARR_DIGITS+5, a
	movlw	DIGIT6
	movwf	ARR_DIGITS+6, a
	movlw	DIGIT7
	movwf	ARR_DIGITS+7, a
	movlw	DIGIT8
	movwf	ARR_DIGITS+8, a
	movlw	DIGIT9
	movwf	ARR_DIGITS+9, a
ENDM

inc_num:;(void) -> void
	incf	RIGHT_DIGIT, a
	movf	RIGHT_DIGIT, w, a
	sublw	10
	bnz	_inc_num_end
	; if RIGHT_DIGIT == 10
		clrf	RIGHT_DIGIT, a
		incf	LEFT_DIGIT, a
		movf	LEFT_DIGIT, w, a
		sublw	10
		bnz	_inc_num_end
		; if LEFT_DIGIT == 10
			clrf	LEFT_DIGIT, a
	_inc_num_end:
	return

dec_num:;(void) -> void
	decf	RIGHT_DIGIT, a
	movf	RIGHT_DIGIT, w, a
	sublw	0xFF
	bnz	_dec_num_end
	; if RIGHT_DIGIT == 0xFF
		movlw	9
		movwf	RIGHT_DIGIT, a
		decf	LEFT_DIGIT, a
		movf	LEFT_DIGIT, w, a
		sublw	0xFF
		bnz	_dec_num_end
		; if LEFT_DIGIT == 0xFF
			movlw	9
			movwf	LEFT_DIGIT, a
	_dec_num_end:
	return

num_to_digit:;(int) -> int
	movwf	FSR0L, a
	movlw	ARR_DIGITS
	addwf	FSR0L, F, a
	movf	INDF0, w, a
	return

num_to_bin:;(void) -> int
	movf	LEFT_DIGIT, w, a
	addwf	LEFT_DIGIT, w, a
	addwf	LEFT_DIGIT, w, a
	addwf	LEFT_DIGIT, w, a
	addwf	LEFT_DIGIT, w, a
	rlncf	WREG, w, a
	addwf	RIGHT_DIGIT, w, a	
	return

delay:;(void) -> void
	incf	DELAY_COUNTER, a
	bnz	delay
	return

super_delay:;(void) -> void
	call	delay
	incf	SUPER_DELAY_COUNTER, a
	bnz	super_delay
	return

read_pb2:;(void) -> int
	movf	PORTB, w, a
	comf	WREG, a
	andlw	0b00000001
	return

read_pb1:;(void) -> int
	movf	PORTJ, w, a
	comf	WREG, a
	andlw	0b00100000
	return

start:
	init_digits_arr
	
	; init TRIS states
	clrf	TRISF, a
	bcf	TRISH, 0, a
	bcf	TRISH, 1, a
	bcf	TRISA, 4, a
	bsf	TRISB, 0, a
	bsf	TRISJ, 5, a
	bsf	TRISH, 4, a
	bsf	TRISH, 5, a
	bsf	TRISH, 6, a
	bsf	TRISH, 7, a
	bsf	TRISC, 2, a
	bsf	TRISC, 3, a
	bsf	TRISC, 4, a
	bsf	TRISC, 5, a
	
	; digital input mode
	movlw	0x0F
	movwf	ADCON1, a
	
	; init number
	movlw	0
	movwf	LEFT_DIGIT, a
	movlw	0
	movwf	RIGHT_DIGIT, a
	
	; init BP states
	call	read_pb2
	movwf	LEFT_PB_PREV, a
	call	read_pb1
	movwf	RIGHT_PB_PREV, a

loop:
	; IO ports:
	; RFx -> General output (inverted for 7-segments, normal for bulbs)
	; RH0 -> Q1 (capacitor for right 7-segment display, inverted)
	; RH1 -> Q2 (capacitor for left 7-segment display, inverted)
	; RA4 -> Q3 (capacitor for LED bulbs)
	; RB0 -> PB2 (left push button)
	; RJ5 -> PB1 (right push button)
	; RH4~RH7 -> Left 4 switches
	; RC2~RC5 -> Right 4 switches
	
	; Left push button
	call	read_pb2
	movwf	LEFT_PB_NOW, a
	subwf	LEFT_PB_PREV, w, a
	bz	_left_pb_changed_end
	; if LEFT_PB_NOW != LEFT_PB_PREV
		movf	LEFT_PB_NOW, w, a	; LEFT_PB_PREV = LEFT_PB_NOW
		movwf	LEFT_PB_PREV, a
		bz	_left_pb_changed_end	; only call dec_num on press, not release
		call	dec_num
	_left_pb_changed_end:
	
	; Right push button
	call	read_pb1
	movwf	RIGHT_PB_NOW, a
	subwf	RIGHT_PB_PREV, w, a
	bz	_right_pb_changed_end
	; if LEFT_PB_NOW != LEFT_PB_PREV
		movf	RIGHT_PB_NOW, w, a	; LEFT_PB_PREV = LEFT_PB_NOW
		movwf	RIGHT_PB_PREV, a
		bz	_right_pb_changed_end	; only call inc_num on press, not release
		call	inc_num
	_right_pb_changed_end:
	
	; Switches
	clrf	SWITCHES_NOW, a
	movf	PORTH, w, a
	andlw	0b11110000
	iorwf	SWITCHES_NOW, a
	movf	PORTC, w, a
	andlw	0b00111100
	rrncf	WREG, w, a
	rrncf	WREG, w, a
	iorwf	SWITCHES_NOW, a
	movf	SWITCHES_NOW, w, a
	subwf	SWITCHES_PREV, w, a
	bz	_switches_changed_end
	; if SWITCHES_NOW != SWITCHES_PREV
		movf	SWITCHES_NOW, w, a	; SWITCHES_PREV = SWITCHES_NOW
		movwf	SWITCHES_PREV, a
		movlw	0
		iorwf	LEFT_DIGIT, w, a
		iorwf	RIGHT_DIGIT, w, a
		bz	_switches_changed_end	; skip animation if already zero
		clrf	LEFT_DIGIT, a
		clrf	RIGHT_DIGIT, a
		call	super_delay		; some fun animations
		call	super_delay
		call	super_delay
	_switches_changed_end:
	
	; Left 7-segment display
	movf	LEFT_DIGIT, w, a	; LATF = num_to_digit(LEFT_DIGIT)
	call	num_to_digit
	movwf	LATF, a
	bcf	LATH, 1, a		; Toggle Q2
	call	delay
	bsf	LATH, 1, a
	
	; Right 7-segment display
	movf	RIGHT_DIGIT, w, a	; LATF = num_to_digit(RIGHT_DIGIT)
	call	num_to_digit
	movwf	LATF, a
	bcf	LATH, 0, a		; Toggle Q1
	call	delay
	bsf	LATH, 0, a
	
	; LED bulbs
	call	num_to_bin
	movwf	LATF, a
	bsf	LATA, 4, a		; Toggle Q3
	call	delay
	bcf	LATA, 4, a
	
	bra loop
	end
