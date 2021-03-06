
		processor 6502
		seg program
        
		org $9400
        
SPI_SS		equ $C0C1		; SPI card commands (assumes slot 4)
SPI_EXEC	equ $C0C0
SPI_DATA	equ $C0C2
SPI_RESET	equ $C0C3

A2_WAIT		equ $FCA8		; Apple Monitor ROM WAIT function

ZP_CMD_PKG	equ $EB			; command and data bytes for spi_cmd
ZP_CMD_STAT	equ $EB			
ZP_DATAH	equ $EC
ZP_DATAL	equ $ED

ZP_LENH		equ $EE			; registers for upload_verify
ZP_LENL		equ $EF
ZP_VERIFY	equ $FF 		; set to $80 to verify, $00 to write
ZP_SRC_PTR	equ $F9

;-----------------------------------------------------------------------------------------
; Execute SPI command. Writes command and two data bytes. Reads status and two data bytes.
;-----------------------------------------------------------------------------------------
		SUBROUTINE
SPICmd		ldx #$00
        	lda #$01		; use SPI channel 0 (set bit 0)
        	sta SPI_SS		; begin SPI transaction
                lda #$01
                jsr A2_WAIT		; wait for INIT puse to finish (30 uS)
.nextByte	lda ZP_CMD_PKG,x	; load byte (one command byte, two data bytes)
                sta SPI_DATA		; store in SPI data latch
                sta SPI_EXEC		; execute SPI transfer
.wait		lda SPI_SS		; get transfer status
                bpl .wait		; wait until all 8 bits are sent
                lda SPI_DATA		; get reply byte from SPI data latch
                sta ZP_CMD_PKG,x	; store byte (one status byte, two data bytes)
                inx
                cpx #$03
                bne .nextByte		; repeat for all three bytes
                sta SPI_RESET		; end SPI transaction
                rts

;----------------------------------------------------------------------------------------
; upload and verify - furnish length and verify flag. 
; Returns with $FF in VERIFY if error, Y register in LENL.
;----------------------------------------------------------------------------------------
		SUBROUTINE
UploadVerify	lda #$00		; initialize pointers and page end
		sta .pageEnd+1
                lda #$04
                sta ZP_SRC_PTR
                lda #$20
                sta ZP_SRC_PTR+1
                
                lda ZP_LENH		; if less than one page, go right to final page
                beq .finalPage
.nextPage	ldy #$00
.pageLoop	lda ZP_VERIFY		; if verify set, verify, otherwise send
                bmi .verify
                
.send		lda (ZP_SRC_PTR),y	; data starts at $2000
		sta ZP_DATAH		
		iny 
                lda (ZP_SRC_PTR),y	; move hi and lo bytes into spi data storage
		sta ZP_DATAL
                lda #$90		; $90 = write command
                sta ZP_CMD_STAT		; move command into spi command storage
                jsr SPICmd		; execute spi transaction
                jmp .common

.verify		lda #$80		; $80 = read command
		sta ZP_CMD_STAT		; move command into spi command register
		jsr SPICmd		; execute spi transaction
                lda (ZP_SRC_PTR),y	
                cmp ZP_DATAH		; compare data bytes to what was read
                bne .error		; error if not the same
                iny
                lda (ZP_SRC_PTR),y
                cmp ZP_DATAL
                bne .error
                
.common          lda #$01
                jsr A2_WAIT		; wait for SPI EXECUTE pulse to finish (60 µs)
                iny      
.pageEnd	cpy #$00		; check to see if done with page
		bne .pageLoop		; (including partial page)
		lda ZP_LENH
                beq .finalPage
                inc ZP_SRC_PTR+1	; add one to data pointer hi byte
                dec ZP_LENH
                jmp .nextPage		; read or verify next page
                
.finalPage	lda ZP_LENL		; if length lo byte is >0, put it in page_end compare
		beq .end
                sta .pageEnd+1
                lda #$00
                sta ZP_LENL		; zero out lo byte for next time
                jmp .nextPage		; and read or verify next (partial) page
                
.error		lda #$ff		; set error flag
		sta ZP_VERIFY
                sty ZP_LENL		; store current y reg for analysis
.end		rts
	
                
        
        
        


