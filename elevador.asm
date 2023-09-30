/* 
Microcontroladores e Aplicações 2023.1
Professor: Erick Barboza
Projeto: Elevador de 3 pisos
Plataforma: Microcontrolador ARV-ATMEGA328P
Autores:
	Daniel Pessoa Máximo
	Lívia de Maria Calado Machado Soares
	Matheus Vieira Faria
	Rangel Gonçalves
*/

.def vector_OUT = r21 ;[buzzer, led, x, x, x, x]
.def tempIO = r20
.def vector01=r19 ;[inpC_Terreo,inpC01,inpC02,inpT_Terreo,inpT01,inpT02,abrirPorta, fecharPorta]-------v]
.def vector02=r18 ;[sttPort,buzzer,parado/andando,LED,Andar2,Andar1,Andar0] ---> [ sttPort 1 = aberto; 0 = fechado] ----> parado = 0 andando = 1
.def contador=r17 
.def temp = r16
.def pilhachamados = r22
.def guardaAndar = r23
jmp reset
.org OC1Aaddr
jmp OC1A_Interrupt


OC1A_Interrupt:
push r16
in r16, SREG
push r16

inc r17
;ldi contador, 30

pop r16
out SREG, r16
pop r16
reti

reset:
	ldi r17, 0
	lds r16, TIMSK1
	sbr r16, 1 <<OCIE1A
	sts TIMSK1, r16
.cseg
	ldi tempIO, 0b00000000
	out DDRD, tempIO
	ldi tempIO, 0b00111111
	out DDRB, tempIO
;.undef tempIO
;.def pilhachamados = r20
ldi pilhachamados, 0
;Stack initialization
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	#define CLOCK 16.0e6 ;clock speed
	.equ PRESCALE = 0b100 ;/256 prescale
	.equ PRESCALE_DIV = 256
	#define DELAY 1 ;seconds
	.equ WGM = 0b0100 ;Waveform generation mode: CTC
	;you must ensure this value is between 0 and 65535
	.equ TOP =	int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"
	.endif

	;On MEGA series, write high byte of 16-bit timer registers first
	ldi temp, high(TOP) ;initialize compare value (TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp

	ldi temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM
	sts TCCR1A, temp
	;upper 2 bits of WGM and clock select
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	sts TCCR1B, temp ;start counter
	sei;
	ldi vector02, 0b00000001 ; inicia o elevador estando no andar 1, com portas fechadas,buzzer e led desligados

main: 
	in vector01, PIND; pega os valores de entrada
	; entra nas funções de chamada para um andar (pessoa fora do elevador)
	cpi vector01, 0 ; se o valor total do reg for 0 é pq não tem entradas e ele esta parado/ocioso
	breq GoToTimes  ; se não tiver entradas vai pro estado parado
	sbrc vector01, 1 ; se o botão de abrir porta for pressionado 
		jmp AbrirPorta
	sbrc vector01, 0 ; se o botão de fechar porta for pressionado 
		jmp FecharPorta 
	jmp Andar2Funcoes ; começa verificando as chamadas pelo andar mais alto [PRIORIDADE]

	; função para escolher o andar
	SelectTarget:
		jmp Target0

	; funções de tempo
	GoToTimes:
		;cpi pilhachamados, 0
		;brne chamados
		sbrc vector02, 4 ; se o elevador estiver parado pula a função delaymovimento
		jmp delayMomimento; vai contar ate 3 sem fazer mais nada pq quando o elevador andar ele não pode fazer outra coisa
		jmp delayParado ; quando o elevador estiver parado ele vai contar ate 5 e ligar o buzzer e depois ate 10 e 
						; deslicar led e buzzer e fechar a porta
fim:
	rcall setOutputs ; envia os valores para a porta de saida [PORTB]
	jmp main

Andar0Funcoes:
	sbrc vector01, 7 ; verifica se tem chamado para o andar 0
    rjmp case00

	sbrc vector01, 6  ; verifica se tem chamado para o andar 1  
		jmp case01

	sbrc vector01, 5  ; verifica se tem chamado para o andar 2 
		jmp case02

jmp SelectTarget

	case00: ;if(andarAtual==andarCall)-> abre porta
		jmp AbrirPorta

	case01:
		sbr vector01, (1 << 3) ; dou um set pq é oq vai fazer o elevador se mover ate lá 0->1
		jmp SelectTarget 

	case02: 
		sbr vector01, (1 << 2) ; dou um set pq é oq vai fazer o elevador se mover ate lá 0->2
		jmp SelectTarget

Andar1Funcoes:
	;essa parte verifica o andar atual e direciona o codigo para as funções do andar correto
	sbrc vector02, 0
		jmp Andar0Funcoes
	;fim do direcionamento de andar

	sbrc vector01, 7 ; verifica se tem chamado para o andar 0
    rjmp case10 

	sbrc vector01, 6 ; ve1ifica se tem chamado para o andar 0
		jmp case11

	sbrc vector01, 5 ; verifica se tem chamado para o andar 2
		jmp case12

	jmp Andar0Funcoes

	case10:
		sbr vector01, (1 << 4) ; dou um set pq é oq vai fazer o elevador se mover ate lá 1->0
		jmp SelectTarget 

	case11: ;if(andarAtual==andarCall)-> abre porta
		call AbrirPorta
		rjmp fim 

	case12:
		sbr vector01, (1 << 2) ; dou um set pq é oq vai fazer o elevador se mover ate lá 1->2
		jmp SelectTarget 


Andar2Funcoes:
	;essa parte verifica o andar atual e direciona o codigo para as funções do andar correto
	sbrc vector02, 1
		jmp Andar1Funcoes
	sbrc vector02, 0
		jmp Andar0Funcoes
	;fim do direcionamento de andar


	sbrc vector01, 7 ; verifica se tem chamado para o andar 0
    jmp case20

	sbrc vector01, 6  ; verifica se tem chamado para o andar 1
		jmp case21

	sbrc vector01, 5  ; verifica se tem chamado para o andar 2
		jmp case22
	jmp Andar1Funcoes
	case20:
		sbr vector01, (1 << 4) ; dou um set pq é oq vai fazer o elevador se mover ate lá 2->0
		jmp SelectTarget
		 
	case21: 
		sbr vector01, (1 << 3) ; dou um set pq é oq vai fazer o elevador se mover ate lá 2->1
		jmp SelectTarget
		 
	case22: ;if(andarAtual==andarCall)-> abre porta
		jmp AbrirPorta

Target0:
	sbrc vector01, 4 ; verifica se quer ir para o andar 0
    jmp caseT00  

	sbrc vector01, 3  ; verifica se quer ir para o andar 1
		jmp caseT01

	sbrc vector01, 2 ; verifica se quer ir para o andar 2 
		jmp caseT02

	jmp GoToTimes 

	;vector02 = [sttPort,buzzer,parado/andando,LED,Andar2,Andar1,Andar0]
	caseT00:
		;delayMomimento
		sbr vector02, (1 << 4) ; Elevador andando
		cbr vector02, (1 << 3) ; desliga a led
		cbr vector02, (1 << 5) ; tem que desligar o buzzer se ele for andar pode existir o caso de chamarem com o buzzer ligado
		rcall setOutputs
		mov guardaAndar, vector02
		sbr vector02, (1 << 0) ; -.
		cbr vector02, (1 << 1) ;  :--indica que esta no andar 0
		cbr vector02, (1 << 2) ; _:
		jmp GoToTimes 
	caseT01: 
		;delayMomimento
		sbr vector02, (1 << 4) ; Elevador andando
		cbr vector02, (1 << 3) ;desliga a led
		cbr vector02, (1 << 5) ; tem que desligar o buzzer se ele for andar pode existir o caso de chamarem com o buzzer ligado
		rcall setOutputs
		mov guardaAndar, vector02
		sbr vector02, (1 << 1) ; -.
		cbr vector02, (1 << 0) ;  :--indica que esta no andar 1 
		cbr vector02, (1 << 2) ; _:
		jmp GoToTimes 
	caseT02: ;guardaAndar
		;delayMomimento
		sbr vector02, (1 << 4) ; Elevador andando
		cbr vector02, (1 << 3) ;desliga a led
		cbr vector02, (1 << 5) ; tem que desligar o buzzer se ele for andar pode existir o caso de chamarem com o buzzer ligado
		rcall setOutputs
		mov guardaAndar, vector02
		sbr vector02, (1 << 2) ; -.
		cbr vector02, (1 << 0) ;  :--indica que esta no andar 2
		cbr vector02, (1 << 1) ; _:
		jmp GoToTimes 

delayParado:
	; Comparação com 5
	;subi contador, -5 ; LEMBRAR DE APAGAR ISSO AQUI
	cpi contador, 5 ; verifica se o contador ja chegou ate 5
	breq igual_a_5 ; tratamento se for igual a 5

	; Comparação com 10
	cpi contador, 10 ; verifica se o contador ja chegou ate 10 
	breq igual_a_10 ; tratamento se for igual a 10

	jmp retorne ; Se não for igual a 5 nem a 10 volto pra main

	; Label para o caso em que contador é igual a 5
	;[sttPort,buzzer,parado/andando,LED,Andar2,Andar1,Andar0]
	igual_a_5:
		cpi pilhachamados, 0
		brne chamados
		sbrc vector02, 6 ;somente liga o buzzer se a porta estiver aberta
		sbr vector02, (1 << 5) ; se for igual a 5 ligar o buzzer
	;rcall setOutputs
	jmp retorne

	; Label para o caso em que contador é igual a 10
	;[sttPort,buzzer,parado/andando,LED,Andar2,Andar1,Andar0]
	igual_a_10:
		cbr vector02, (1 << 5) ; se forigual a 10 desliga o buzzer
		cbr vector02, (1 << 6) ; muda o status da porta par fechado
		cbr vector02, (1 << 3) ; desliga a led

	retorne: 
		jmp fim

chamados:
	sbrc pilhachamados, 5 ; chamado pro segundo andar em aguardo
		jmp dequeue2

	sbrc pilhachamados, 6 ; chamado pro primeiro andar em aguardo
		jmp dequeue1

	sbrc pilhachamados, 7 ; chamado pro terreo andar em aguardo
		jmp dequeue0
	
	jmp main
	;[inpC_Terreo,inpC01,inpC02,inpT_Terreo,inpT01,inpT02,abrirPorta, fecharPorta]-------v]
	dequeue2:
		cbr pilhachamados, (1 << 5)
		;sbr vector01, (1 << 2)
		sbr vector01, (1 << 5)
		jmp Andar2Funcoes
	dequeue1:
		cbr pilhachamados, (1 << 6)
		;sbr vector01, (1 << 3)
		sbr vector01, (1 << 6)
		jmp Andar2Funcoes
	dequeue0:
		cbr pilhachamados, (1 << 7)
		;sbr vector01, (1 << 4)
		sbr vector01, (1 << 7)
		jmp Andar2Funcoes
	jmp main

;[sttPort,buzzer,parado/andando,LED,Andar2,Andar1,Andar0]

Esperando_verificacao:
	ldi contador, 0
	sbrc guardaAndar, 1
		jmp EsperandoContador
	sbrc vector01, 3
		jmp EsperandoContador
	sbrc vector01, 6
		jmp EsperandoContador
	EsperandoContador_2:
		in temp, PIND
		sbrc temp, 5
			sbr pilhachamados, (1 << 5)
		sbrc temp, 6
			sbr pilhachamados, (1 << 6)
		sbrc temp, 7
			sbr pilhachamados, (1 << 7)

		cpi contador, 3 ;caso contador for igual a 3, pula para abrir porta
		breq retorno_verificacao
		jmp EsperandoContador_2 ; se movendo entre andares, fica em loop ate o contardor chegar a 3

delayMomimento:
	sbr vector02, (1 << 4) ; indico que o elevador esta andando
	cbr vector02, (1 << 3) ; desligo a led
	;rcall setOutputs ;vou atualizar a saida [acho que não tenha necessidade de usar aqui pois o abrir porta tbm chama ela]
	jmp Esperando_verificacao
	retorno_verificacao:
		ldi contador, 0
		ldi temp, 0b00000001
		OUT PORTB, temp
	EsperandoContador:
		in temp, PIND
		sbrc temp, 5
			sbr pilhachamados, (1 << 5)
		sbrc temp, 6
			sbr pilhachamados, (1 << 6)
		sbrc temp, 7
			sbr pilhachamados, (1 << 7)
		cpi contador, 3 ;caso contador for igual a 3, pula para abrir porta 
		breq AbrirPorta
		jmp EsperandoContador ; se movendo entre andares, fica em loop ate o contardor chegar a 3 

;[sttPort,buzzer,parado/andando,LED,Andar2,Andar1,Andar0]
;[buzzer, led, x, x, x, x]
AbrirPorta:
	ldi contador, 0 ; zera o contador para começar a contagem ate 5 no delayparado
	sbr vector02, (1 << 6) ; indica que a porta se abriu
	cbr vector02, (1 << 4) ; indico que o elevador esta parado
	sbr vector02, (1 << 3) ; ligo a led
	;cbr vector01, (1 << 1) ; desativo o sinal de abrir porta
	sbr vector_OUT, (1 << 4) ; ligo a led no vetor de saida
	rcall setOutputs
	jmp delayParado

FecharPorta:
	ldi contador, 5 ; zera o contador para começar a contagem ate 5 no delayparado
	cbr vector02, (1 << 6) ; indica que a porta se fechou
	cbr vector02, (1 << 4) ; indico que o elevador esta parado
	cbr vector02, (1 << 3) ; desligo a led
	cbr vector02, (1 << 5) ; desligo a buzzer
	cbr vector01, (1 << 0) ; desativo o sinal de fechar porta
	cbr vector_OUT, (1 << 4) ; desligo a led no vetor de saida

	jmp fim

setOutputs:
	rcall atualizaVector_Out
	out PORTB, vector_OUT ;Manda as informações de saída para o portB
	ret
		

;[buzzer, led, x, x, x, x]
;[sttPort,buzzer,parado/andando,LED,Andar2,Andar1,Andar0]
atualizaVector_Out:
	sbrc vector02, 3 ; verifica se a porta esta aberta
		sbr vector_OUT, (1 << 4) ; se sim liga a led
		sbrs vector02, 3 ; verifica se a porta esta fechada 
		cbr vector_OUT, (1 << 4) ; se sim desliga a led
	
	sbrc vector02, 5 ; verifica se o buzzer pdeve ser ligado
		sbr vector_OUT, (1 << 5) ; se sim liga o buzzer na saida
		sbrs vector02, 5 ; verifica se o buzzer pdeve ser desligado
		cbr vector_OUT, (1 << 5) ; se sim desliga o buzzer na saida

	sbrc vector02, 0 ; verifica se esta no andar 0
		jmp display0
	sbrc vector02, 1 ; verifica se esta no andar 1
		jmp display1
	sbrc vector02, 2 ; verifica se esta no andar 2
		jmp display2

	display0:
		cbr vector_OUT, (1 << 0) ;-.
		cbr vector_OUT, (1 << 1) ; :
		cbr vector_OUT, (1 << 2) ; :--> exibe o andar 0 display[valor 0000]
		cbr vector_OUT, (1 << 3) ;_:
		;sbr vector_OUT, (1 << 4) ;ligando o led de porta aberta
		jmp fimCase
	display1:
		sbr vector_OUT, (1 << 0) ;-.
		cbr vector_OUT, (1 << 1) ; :
		cbr vector_OUT, (1 << 2) ; :--> exibe o andar 0 display[valor 0001]
		cbr vector_OUT, (1 << 3) ;_:
		;sbr vector_OUT, (1 << 4) ;ligando o led de porta aberta
		jmp fimCase
	display2:
		cbr vector_OUT, (1 << 0) ;-.
		sbr vector_OUT, (1 << 1) ; :
		cbr vector_OUT, (1 << 2) ; :--> exibe o andar 0 display[valor 0010]
		cbr vector_OUT, (1 << 3) ;_:
		;sbr vector_OUT, (1 << 4) ;ligando o led de porta aberta
		jmp fimCase

	fimCase:
		ret
