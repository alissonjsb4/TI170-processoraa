`timescale 1ns / 1ps

//===================================================================================================================================
// MÓDULO 1: LEITOR DE ARQUIVO EXTERNO GERADO PELO COMPILADOR
//===================================================================================================================================

module file_reader(
    input wire clock,
    input wire reset,
    output reg [7:0] data_out,   // Dados lidos do arquivo
);
    // Memória simulando um arquivo externo
    reg [7:0] file_memory [0:127]; // Arquivo com 128 linhas
    reg [6:0] line_counter;       // Contador de linhas do arquivo

    // Inicializando o arquivo com dados binários
    initial begin
        $readmemb("file.bin", file_memory); // Lê o arquivo binário
        line_counter = 0;
    end

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            line_counter <= 0;
        end else if (line_counter < 128) begin
            data_out <= file_memory[line_counter]; // Envia uma linha
            line_counter <= line_counter + 1;      // Próxima linha
        end 
    end
endmodule

//===================================================================================================================================
// MÓDULO 2: MEMÓRIA DE DADOS, O PRINCIPAL REGISTRADOR DO PROCESSADOR
//===================================================================================================================================

module data_memory(RAM) (
    input clock,                // Sinal de clock
    input reset,                // Sinal de reset ativo baixo
    input [7:0] address,        // Endereço de memória
    input [7:0] data_in,        // Dados de entrada para a memória
    input write,                // Sinal de escrita
    output reg [7:0] data_out   // Dados de saída da memória
);

    // Declaração da memória de dados (endereço de 0 a 127)
    reg [7:0] RW[0:127];

    // Habilitação interna da memória de dados
    reg EN;
    always @ (address) begin
        if ((address >= 0) && (address <= 127)) 
            EN = 1'b1;
        else 
            EN = 1'b0;
    end

    // Lógica de leitura e escrita na memória de dados
    always @ (posedge clock) begin
        if (write && EN) begin
            RW[address] <= data_in;  // Escreve dados na memória
        end else if (!write && EN) begin
            data_out <= RW[address];  // Lê dados da memória
        end
    end

endmodule

//===================================================================================================================================
// MÓDULO 3: CAMINHO DE DADOS, O MÓDULO QUE DESEHA O TRAJETO QUE OS DADOS FARÃO AO LONGO DA EXECUÇÃO DE SUAS INSTRUÇÕES
//===================================================================================================================================

module caminho_dados (
    input wire clock, reset,
    input wire [2:0] Bus1_Sel,
    input wire [1:0] Bus2_Sel,
    input wire PC_Load, PC_Inc, PR_Inc, A_Load, B_Load, C_Load, IR_Load, MAR_Load, CCR_Load, Memory_Load,
    input wire [7:0] ALU_Result, from_memory, NZVC,
    output reg [7:0] to_memory, address,
    output reg [7:0] IR, A, B, C, PC, MAR, PR, CCR_Result
);

    // Barramentos
    reg [7:0] Bus1, Bus2;

    // Multiplexador para Bus1
    always @(*) begin
        case (Bus1_Sel)
            3'b000: Bus1 = PC;
            3'b001: Bus1 = A;
            3'b010: Bus1 = B;
            3'b011: Bus1 = C;
            3'b100: Bus1 = PR;
            3'b101: Bus1 = IR;
            default: Bus1 = 8'hXX;
        endcase
    end

    // Multiplexador para Bus2
    always @(*) begin
        case (Bus2_Sel)
            2'b00: Bus2 = Bus1;
            2'b01: Bus2 = 8'h01;
            2'b10: Bus2 = from_memory;
            2'b11: Bus2 = ALU_Result;
            default: Bus2 = 8'hXX;
        endcase
    end

    // Conexão de memória
    always @(posedge clock or negedge reset) begin
        if(Memory_Load) begin
            to_memory = Bus1;
            address = MAR;
        end
    end

    // Registrador de Instrução (IR)
    always @(posedge clock or negedge reset) begin
        if (!reset)
            IR <= 8'h00;
        else if (IR_Load)
            IR <= Bus2;
    end

    // Registrador de Endereço de Memória (MAR)
    always @(posedge clock or negedge reset) begin
        if (!reset)
            MAR <= 8'h00;
        else if (MAR_Load)
            MAR <= Bus2;
    end

    // Contador de Programa (PC) com Incremento
    always @(posedge clock or negedge reset) begin
        if (!reset)
            PC <= 8'h00;
        else if (PC_Load)
            PC <= PC + Bus2;
        else if (PC_Inc)
            PC <= PC + 1;
    end

    // Incremento de Contador de Resposta (PR)
    always @(posedge clock or negedge reset) begin
        if (!reset)
            PR <= 8'h00;
        else if (PR_Inc)
            PR <= PR + 1;
    end
    
    // Registradores A, B e C
    always @(posedge clock or negedge reset) begin
        if (!reset)
            A <= 8'h00;
        else if (A_Load)
            A <= Bus2;
    end

    always @(posedge clock or negedge reset) begin
        if (!reset)
            B <= 8'h00;
        else if (B_Load)
            B <= Bus2;
    end

    always @(posedge clock or negedge reset) begin
        if(!reset)
            C <= 8'h00;
        else if (C_Load)
            C <= Bus2;
    end

    // Registrador de Códigos de Condição (CCR)
    always @(posedge clock or negedge reset) begin
        if (!reset)
            CCR_Result <= 8'h00;
        else if (CCR_Load)
            CCR_Result <= NZVC;
    end

endmodule

//===================================================================================================================================
// MÓDULO 4: UNIDADE DE CONTROLE, RESPONSÁVEL POR DECIDIR COMO OS DADOS SERÃO CARREGADOS E UTILIZADOS ENTRE AS PRINCIPAIS UNIDADES
//===================================================================================================================================

module control_unit (
    input clock,               // Clock de entrada
    input reset,               // Reset ativo baixo
    input [7:0] IR,            // Registrador de Instrução
    input CCR_Result,          // Resultado do registrador de condições (CCR)
    output reg IR_Load,        // Sinal para carregar o registrador de instrução
    output reg MAR_Load,       // Sinal para carregar o registrador de endereço de memória
    output reg MARR_Load,       // Sinal para carregar o registrador de endereço de memória da resposta
    output reg PC_Load,        // Sinal para carregar o registrador de contador de programa (PC)
    output reg PR_Load,        // Sinal para carregar o registrador de contador de resposta (PR)
    output reg PC_Inc,         // Sinal para incrementar o PC
    output reg Memory_Load     // Sinal para carregar uma informação na memória de dados (RAM)
    output reg A_Load,         // Sinal para carregar o registrador A
    output reg B_Load,         // Sinal para carregar o registrador B
    output reg [3:0] ALU_Sel,  // Seleção da ALU
    output reg CCR_Load,       // Sinal para carregar o registrador de condições
    output reg [1:0] Bus1_Sel, // Seleção para o barramento 1
    output reg [1:0] Bus2_Sel, // Seleção para o barramento 2
    output reg write           // Sinal de escrita em memória ou registradores
    output reg file_finished   // Sinal para indicar que o arquivo foi terminado, iniciando a criação do arquivo de resposta
);

    // Definição dos estados
    reg [7:0] current_state, next_state;

    // Definindo os estados da máquina de estados
    parameter S_FETCH_0 = 0, S_FETCH_1 = 1, S_FETCH_2 = 2, S_DECODE_3 = 3; // Estados 0, 1 e 2 de busca, e o Estágio de Decodificar a instrução;
    
    parameter S_LDA_IMM_4 = 4, S_LDA_IMM_5 = 5, S_LDA_IMM_6 = 6;           // Carregam um valor determinado para o Registrador A
    parameter S_LDA_DIR_4 = 7, S_LDA_DIR_5 = 8, S_LDA_DIR_6 = 9;           // Carreagam um valor de memória para o Registrador A
    parameter S_STA_DIR_4 = 12, S_STA_DIR_5 = 13;                          // Guardam o valor do Registrador A na memória
    
    parameter S_LDB_IMM_4 = 14, S_LDB_IMM_5 = 15, S_LDB_IMM_6 = 16;        // Carregam um valor determinado para o Registrador B
    parameter S_LDB_DIR_4 = 17, S_LDB_DIR_5 = 18, S_LDB_DIR_6 = 19;        // Carregam um valor da memória para o Registrador B
    parameter S_STB_DIR_10 = 22, S_STB_DIR_11 = 23, S_STB_DIR_12 = 24;     // Guardam o valor do Registrador B na memória

    parameter ALU_7 = 25, JMP = 26;                                        // Executam operações após coleta de instrução e operando(s)

    parameter S_STIR_DIR_8 = 32, S_STIR_DIR_9 = 33;                        // Guardam o valor do Registrador IR na memória
    
    parameter S_STC_DIR_10 = 42, S_STC_DIR_11 = 43, S_STC_DIR_12= 44;      // Guardam o valor do Registrador C na memória 

    parameter END_OF_ALL = 100;                                            // Estado que termina a coleta e análise de instruções e ativa o processamento das respostas;

    // Outros estados podem ser definidos conforme a necessidade...

    // Memória de estado (atualiza o estado atual)
    always @ (posedge clock or negedge reset) begin
        if (!reset)
            current_state <= S_FETCH_0;  // Estado inicial após reset
        else
            current_state <= next_state; // Atualiza para o próximo estado
    end

    // Lógica de próximo estado (transições de estados)
    always @ (current_state, IR, CCR_Result) begin
        case (current_state)
            // Estados de coleta da instrução e interpretação (ela é de operação ou salto?)
            S_FETCH_0: next_state <= S_FETCH_1;
            S_FETCH_1: next_state <= S_FETCH_2;
            S_FETCH_2: next_state <= S_DECODE_3;
            S_DECODE_3: begin
                if      (IR == 8'h00) next_stage <= END_OF_ALL;
                else if (IR == 8'h04) next_state <= S_LDB_DIR_4;
                else                  next_state <= S_LDA_DIR_4;
            end

            // Estados de coleta do primeiro operando e interpretação (é preciso outro operando ou não?)
            S_LDA_DIR_4: next_state <= S_LDA_DIR_5;
            S_LDA_DIR_5: next_state <= S_LDA_DIR_6;
            S_LDA_DIR_6: begin
                if(IR == 8'h03)                     next_state <= ALU_7;
                else if(IR == 8'h01 or IR == 8'h02) next_state <= S_LDB_IMM_4;
                else                                next_state <= S_LDB_DIR_4;
            end

            // Estados em que o Registrador B recebe um valor predefinido (sua única utilização atual
            // é de receber 8'h01, utilizado para incremento ou decremento do operando A)
            S_LDB_IMM_4: next_stage <= S_LDB_IMM_5;
            S_LDB_IMM_5: next_stage <= S_LDB_IMM_6;
            
            // Estados da coleta do segundo operando (ou do tamanho do salto) e interpretação (é um segundo operando ou o tamanho de um salto?)
            S_LDB_DIR_4: next_state <= S_LDB_DIR_5;
            S_LDB_DIR_5: next_state <= S_LDB_DIR_6;
            S_LDB_DIR_6: begin
                if(IR == 8'h04) next_state <= JMP_7;
                else next_state <= ALU_7;
            end

            // Estados que incorporam gravar a instrução que foi executada na memória de respostas;
            ALU_7: next_stage <=  S_STIR_DIR_8;
            
            // Estado de Jump: apenas pula a quantidade de instruções pedidas;
            JMP_7: next_stage <= S_STIR_DIR_8;
            
            S_STIR_DIR_8: next_stage <= S_STIR_DIR_9;
            S_STIR_DIR_9: if(IR == 8'h04) next_stage <= S_STB_DIR_10;
                          else            next_stage <= S_STC_DIR_10;

            // Estados que incorporam a saída C à memória de respostas; 
            S_STB_DIR_10: next_stage <=  S_STB_DIR_11;
            S_STB_DIR_11: next_stage <= S_STB_DIR_12;
            S_STB_DIR_12: next_stage <= S_FETCH_0;
            
            // Estados que incorporam a saída C à memória de respostas; 
            S_STC_DIR_10: next_stage <=  S_STC_DIR_11;
            S_STC_DIR_11: next_stage <= S_STC_DIR_12;
            S_STC_DIR_12: next_stage <= S_FETCH_0;

            default: next_state <= S_FETCH_0;
        endcase
    end

    // Lógica de saída (controles de sinal conforme o estado atual)
    always @ (current_state) begin
        // Inicializa todos os sinais em 0
        IR_Load = 0;
        MAR_Load = 0;
        PC_Load = 0;
        PC_Inc = 0;
        PR_Inc = 0;
        Memory_Load = 0;
        A_Load = 0;
        B_Load = 0;
        CCR_Load = 0;
        Bus1_Sel = 3'b000;
        Bus2_Sel = 2'b00;
        write = 0;

        case (current_state)
            S_FETCH_0: begin
                MAR_Load = 1;  // Carregar endereço do opcode
                Bus1_Sel = 3'b000; // "000" -> PC
            end
            S_FETCH_1: begin
                PC_Inc = 1;  // Incrementar PC
            end
            S_FETCH_2: begin
                IR_Load = 1;  // Carregar a instrução
                Bus2_Sel = 2'b10; // "10" -> from memory
            end
            
            S_LDA_DIR_4: begin
                MAR_Load = 1;
                Bus1_Sel = 3'b000;
            end
            S_LDA_DIR_5: begin
                PC_Inc = 1;
            end
            S_LDA_DIR_6: begin
                A_Load = 1;  // Carregar 
                Bus2_Sel = 2'b10;
            end
            
            S_LDB_DIR_4: begin
                MAR_Load = 1;
                Bus1_Sel = 3'b000;
            end
            S_LDB_DIR_5: begin
                PC_Inc = 1;
                B_Load = 1;  // Carregar 
                Bus2_Sel = 2'b10;
            end
            S_LDB_DIR_6: begin
                Bus1_Sel = 3'b010;
                Bus2_Sel = 2'b00;                
            end

            S_LDB_IMM_4: begin
                Bus2_Sel = 2'b01; // Seleciona o valor imediato para o barramento 2
            end
            S_LDB_IMM_5: begin
                B_Load = 1;       // Ativa o carregamento do registrador B
            end
            S_LDB_IMM_6: begin
                next_state = ALU_7; // Retorna ao ciclo de busca
            end

            ALU_7: begin
                case(IR)
                    8'h01: ALU_Sel = 4'h0;  // incremento
                    8'h02: ALU_Sel = 4'h1;  // decremento
                    8'h03: ALU_Sel = 4'h8;  // negação
                 // 8'h04 não é uma instrução da ALU
                    8'h10: ALU_Sel = 4'h0;  // soma
                    8'h20: ALU_Sel = 4'h1;  // subtração
                    8'h30: ALU_Sel = 4'h2;  // multiplicação
                    8'h40: ALU_Sel = 4'h3;  // divisão
                    8'h50: ALU_Sel = 4'h4;  // resto
                    8'h60: ALU_Sel = 4'h6;  // AND
                    8'h70: ALU_Sel = 4'h7;  // OR
                    8'h80: ALU_Sel = 4'hA;  // XOR
                    8'h90: ALU_Sel = 4'hB;  // NAND
                    8'hA0: ALU_Sel = 4'hC;  // NOR
                    8'hB0: ALU_Sel = 4'hD;  // XNOR
                    8'hC0: ALU_Sel = 4'h5;  // comparação
                endcase
            end

            JMP_7: begin
                PC_Load = 1;
                Bus1_Sel = 3'b010;
                Bus2_Sel = 2'b00;
            end

            S_STIR_DIR_8: begin
                MAR_Load = 1;
                Bus1_Sel = 3'b100;
                Bus2_Sel = 2'b00;
            end
            S_STIR_DIR_9: begin
                Memory_Load = 1;
                write = 1;
                Bus1_Sel = 3'b101;
                PR_Inc = 1;
            end

            S_STC_DIR_10: begin
                C_Load = 1;
                Bus2_Sel = 2'b11;
            end
            S_STC_DIR_11 begin
                MAR_Load = 1;
                Bus1_Sel = 3'b100;
                Bus2_Sel = 2'b00;
            end
            S_STC_DIR_12 begin
                Memory_Load = 1;
                write = 1;
                Bus1_Sel = 3'b011;
                PR_Inc = 1;
            end
            
            S_STB_DIR_10: begin
                B_Load = 1;
                Bus1_Sel = 3'010;
                Bus2_Sel = 2'b00;
            end
            S_STB_DIR_11 begin
                MAR_Load = 1;
                Bus1_Sel = 3'b100;
                Bus2_Sel = 2'b00;
            end
            S_STB_DIR_12 begin
                Memory_Load = 1;
                write = 1;
                Bus1_Sel = 3'b010;
                PR_Inc = 1;
            end

            END_OF_ALL begin
                file_finished = 1;
            end
            // Outros estados conforme a lógica necessária
            default: begin
                // Caso de fallback
            end
        endcase
    end

endmodule

//===================================================================================================================================
// MÓDULO 5: UNIDADE LÓGICA E ARITMÉTICA E TODAS SUAS SUB-UNIDADES, RESPONSÁVEL POR CÁLCULOS E OPERAÇÕES LÓGICAS
//===================================================================================================================================

module somador_completo (A, B, Cin, S, Cout);
    input A, B, Cin;        // Entradas do somador completo
    output S, Cout;         // Soma e carry out
    assign S = A ^ B ^ Cin;         // Soma
    assign Cout = (A & B) | (B & Cin) | (A & Cin);  // Carry
endmodule

module SOMADOR_8BITS (A, B, Cin, Soma, Cout);
    input [7:0] A, B;  // Entradas de 8 bits
    input Cin;          // Carry-in
    output [7:0] Soma;  // Resultado da soma de 8 bits
    output Cout;        // Carry-out (overflow)

    wire [7:0] Carry;  // Carry para cada bit
    wire [7:0] Soma_intermediaria;  // Soma intermediária

    // Instanciando os somadores completos, propagando o carry
    somador_completo U0 (A[0], B[0], Cin, Soma_intermediaria[0], Carry[0]);
    somador_completo U1 (A[1], B[1], Carry[0], Soma_intermediaria[1], Carry[1]);
    somador_completo U2 (A[2], B[2], Carry[1], Soma_intermediaria[2], Carry[2]);
    somador_completo U3 (A[3], B[3], Carry[2], Soma_intermediaria[3], Carry[3]);
    somador_completo U4 (A[4], B[4], Carry[3], Soma_intermediaria[4], Carry[4]);
    somador_completo U5 (A[5], B[5], Carry[4], Soma_intermediaria[5], Carry[5]);
    somador_completo U6 (A[6], B[6], Carry[5], Soma_intermediaria[6], Carry[6]);
    somador_completo U7 (A[7], B[7], Carry[6], Soma_intermediaria[7], Carry[7]);

    // Propagando o carry de cada bit para o próximo
    assign Soma = Soma_intermediaria;
    assign Cout = Carry[7];  // Carry-out (overflow)
endmodule

module DIVISOR_8BITS (
    input [7:0] Dividend, Divisor,
    output reg [7:0] Quociente,
    output reg [7:0] Resto
);

    integer i; // Variável para contagem
    reg [7:0] temp_dividend; // Variável para armazenar o dividendo durante a iteração
    
    always @(*) begin
        if (Divisor != 0) begin
            Quociente = 0;
            Resto = Dividend;
            temp_dividend = Dividend;
            
            // Subtração sucessiva
            for (i = 0; i < 8; i = i + 1) begin
                if (temp_dividend >= Divisor) begin
                    temp_dividend = temp_dividend - Divisor;
                    Quociente = Quociente + 1;
                end
            end
            Resto = temp_dividend; // O valor restante é o resto
        end else begin
            Quociente = 8'hFF; // Indicador de erro
            Resto = 8'hFF;     // Indicador de erro
        end
    end
endmodule

module MULTIPLICADOR_8BITS (
    input [7:0] A, B,               // Entradas A e B para multiplicação
    output reg [15:0] Produto       // Resultado da multiplicação (16 bits)
);
    integer i;                      // Índice para o loop
    reg [15:0] temp;                // Variável temporária para armazenar o resultado

    always @(*) begin
        Produto = 16'b0;            // Inicializa o Produto como 0
        temp = {8'b0, A};           // Expande A para 16 bits

        for (i = 0; i < 8; i = i + 1) begin
            if (B[i]) begin          // Se o bit i de B for 1
                Produto = Produto + (temp << i); // Adiciona A deslocado
            end
        end
    end
endmodule

module COMPARADOR (
    input [7:0] A, B,
    output reg [1:0] comparacao_resultado
);

    reg [7:0] diferenca; // Variável para armazenar a diferença entre A e B
    reg sinal_diferenca; // Variável para armazenar o sinal da diferença
    
    always @(*) begin
        diferenca = A - B; // Subtrai A por B
        sinal_diferenca = diferenca[7]; // Verifica o bit de sinal da diferença (bit mais significativo)
        
        // Verifica o sinal da diferença para determinar o resultado da comparação
        if (sinal_diferenca == 0 && diferenca != 0) begin
            comparacao_resultado = 2'b01;  // A é maior
        end else if (sinal_diferenca == 1) begin
            comparacao_resultado = 2'b10;  // A é menor
        end else begin
            comparacao_resultado = 2'b00;  // A é igual a B
        end
    end
endmodule

module ALU (
    input wire [7:0] A, B,             // Operandos de entrada
    input wire [3:0] ALU_Sel,          // Sinal de seleção da operação
    output reg [7:0] C,           // Resultado da operação
    output reg [6:0] Flags,             // Flags: (6) Sinal, (5) Carry, (4) Zero, (3) Paridade, (2) Overflow, (1) Interrupção (0) Direção
    output reg [1:0] comparacao_resultado, // Resultado da comparação: 00 - A == B, 01 - A > B, 10 - A < B
    output reg ALU_Cout               // Carry-out da soma
);

    wire [7:0] Soma, Subtracao, Quociente, Resto;
    wire Soma_Cout, Sub_Cout;
    wire [15:0] Produto;                // Variável para armazenar o produto da multiplicação
    wire [1:0] comparacao_resultado_int; // Resultado interno de comparação

    // Instanciação dos módulos
    SOMADOR_8BITS somador_inst (A, B, 1'b0, Soma, Soma_Cout);
    SOMADOR_8BITS subtrator_inst (A, ~B, 1'b1, Subtracao, Sub_Cout);
    MULTIPLICADOR_8BITS multiplicador_inst (A, B, Produto);
    DIVISOR_8BITS divisor_inst (.Dividend(A),.Divisor(B),.Quociente(Quociente),.Resto(Resto));
    COMPARADOR comparador_inst (.A(A),.B(B),.comparacao_resultado(comparacao_resultado_int));
    
    always @(*) begin
        // Inicializando as flags para zero antes de cada operação
        Flags = 7'b0000000;
        comparacao_resultado = 2'b00;
        
        case (ALU_Sel)
            4'h0: begin  // Soma
                C = Soma;
                Flags[5] = Soma_Cout;  // Carry Flag
                Flags[6] = C[7];   // Sinal (bit mais significativo)
                Flags[4] = (C == 8'h00) ? 1 : 0;  // Zero Flag
                Flags[3] = (^C);  // Paridade (XOR de todos os bits)
                Flags[2] = (A[7] == B[7]) && (C[7] != A[7]);  // Overflow Flag para soma
                Flags[1] = 0; //Não há chances de ser ativada
                Flags[0] = 0; //Não há chances de ser ativada
            end

            4'h1: begin  // Subtração
                // A - B = A + (~B) + 1
                C = Subtracao;
                Flags[5] = (A < B) ? 1 : 0;  // Carry Flag (não aplicável diretamente na subtração, mas pode indicar underflow)
                Flags[6] = C[7];   // Sinal
                Flags[4] = (C == 8'h00) ? 1 : 0;  // Zero Flag
                Flags[3] = (^C);  // Paridade
                Flags[2] = (A[7] != B[7]) && (C[7] != A[7]);  // Overflow Flag para subtração
                Flags[1] = 0; //Não há chances de ser ativada
                Flags[0] = 0; //Não há chances de ser ativada
            end

            4'h2: begin  // Multiplicação
                C = Produto[7:0];
                Flags[6] = 0; //Não há chances de ser ativada
                Flags[5] = 0; //Não há chances de ser ativada
                Flags[4] = (C == 8'h00) ? 1 : 0;  // Zero Flag
                Flags[3] = (^C);  // Paridade
                Flags[2] = (Produto[15:8] != 0) ? 1 : 0;  // Overflow Flag (Se os 8 bits mais significativos forem diferentes de 0, houve overflow)
                Flags[1] = 0; //Não há chances de ser ativada
                Flags[0] = 0; //Não há chances de ser ativada
            end

            4'h3: begin  // Divisão
                if (B != 0) begin
                    C = Quociente;
                    Flags[6] = 0; //Não há chances de ser ativada
                    Flags[5] = 0; //Não há chances de ser ativada
                    Flags[4] = (C == 8'h00) ? 1 : 0;  // Zero Flag
                    Flags[3] = (^C);  // Paridade
                    Flags[2] = (C == 8'h00) ? 1 : 0;
                    Flags[1] = 0;  // Overflow não se aplica
                    Flags[0] = 0;  // Carry não se aplica
                end else begin
                    C = 8'hFF;  // Indicador de erro para divisão por zero
                    Flags = 7'h7F;  // Flags indicativas de erro
                end
            end

            4'h4: begin  // Resto da divisão (Módulo)
                if (B != 0) begin
                    C = Resto;
                    Flags[6] = 0; //Não há chances de ser ativada
                    Flags[5] = 0; //Não há chances de ser ativada
                    Flags[4] = 0; //Não há chances de ser ativada
                    Flags[3] = (^C);  // Paridade
                    Flags[2] = (C == 8'h00) ? 1 : 0;
                    Flags[1] = 0; //Não há chances de ser ativada
                    Flags[0] = 0; //Não há chances de ser ativada
                end else begin
                    C = 8'hFF;
                    Flags = 7'h7F;
                end
            end

            4'h5: begin  // Comparação (A == B)
                C = 8'h00;  // Resultado nulo para comparação
                Flags[6] = 0; //Não há chances de ser ativada
                Flags[5] = 0; //Não há chances de ser ativada
                Flags[4] = 0; //Não há chances de ser ativada
                Flags[3] = 0;
                Flags[2] = (A == B) ? 1 : 0; // Zero Flag
                Flags[1] = 0; //Não há chances de ser ativada
                Flags[0] = 0; //Não há chances de ser ativada
                // Usando o módulo de comparação baseado em subtração
                comparacao_resultado = comparacao_resultado_int;  // Passa o resultado do comparador
            end
            
            4'h6: begin  // AND
                C = A & B;
                Flags[6] = C[7];                     // Sinal Flag
                Flags[5] = 0;                        // Carry Flag (não aplicável)
                Flags[4] = (C == 8'h00) ? 1 : 0;     // Zero Flag
                Flags[3] = (^C);                    // Paridade Flag
                Flags[2] = 0;                        // Overflow Flag (não aplicável)
                Flags[1] = 0;                        // Interrupção (não aplicável)
                Flags[0] = 0;                        // Direção (não aplicável)
            end
            
            4'h7: begin  // OR
                C = A | B;
                Flags[6] = C[7];                     // Sinal Flag
                Flags[5] = 0;                        // Carry Flag (não aplicável)
                Flags[4] = (C == 8'h00) ? 1 : 0;     // Zero Flag
                Flags[3] = (^C);                    // Paridade Flag
                Flags[2] = 0;                        // Overflow Flag (não aplicável)
                Flags[1] = 0;                        // Interrupção (não aplicável)
                Flags[0] = 0;                        // Direção (não aplicável)
            end
            
            4'h8: begin  // NOT A
                C = ~A;
                Flags[6] = C[7];                     // Sinal Flag
                Flags[5] = 0;                        // Carry Flag (não aplicável)
                Flags[4] = (C == 8'h00) ? 1 : 0;     // Zero Flag
                Flags[3] = (^C);                    // Paridade Flag
                Flags[2] = 0;                        // Overflow Flag (não aplicável)
                Flags[1] = 0;                        // Interrupção (não aplicável)
                Flags[0] = 0;                        // Direção (não aplicável)
            end
            
            4'h9: begin  // NOT B
                C = ~B;
                Flags[6] = C[7];                     // Sinal Flag
                Flags[5] = 0;                        // Carry Flag (não aplicável)
                Flags[4] = (C == 8'h00) ? 1 : 0;     // Zero Flag
                Flags[3] = (^C);                    // Paridade Flag
                Flags[2] = 0;                        // Overflow Flag (não aplicável)
                Flags[1] = 0;                        // Interrupção (não aplicável)
                Flags[0] = 0;                        // Direção (não aplicável)
            end
            
            4'hA: begin  // XOR
                C = A ^ B;
                Flags[6] = C[7];                     // Sinal Flag
                Flags[5] = 0;                        // Carry Flag (não aplicável)
                Flags[4] = (C == 8'h00) ? 1 : 0;     // Zero Flag
                Flags[3] = (^C);                    // Paridade Flag
                Flags[2] = 0;                        // Overflow Flag (não aplicável)
                Flags[1] = 0;                        // Interrupção (não aplicável)
                Flags[0] = 0;                        // Direção (não aplicável)
            end
            
            4'hB: begin  // NAND
                C = ~(A & B);
                Flags[6] = C[7];                     // Sinal Flag
                Flags[5] = 0;                        // Carry Flag (não aplicável)
                Flags[4] = (C == 8'h00) ? 1 : 0;     // Zero Flag
                Flags[3] = (^C);                    // Paridade Flag
                Flags[2] = 0;                        // Overflow Flag (não aplicável)
                Flags[1] = 0;                        // Interrupção (não aplicável)
                Flags[0] = 0;                        // Direção (não aplicável)
            end
            
            4'hC: begin  // NOR
                C = ~(A | B);
                Flags[6] = C[7];                     // Sinal Flag
                Flags[5] = 0;                        // Carry Flag (não aplicável)
                Flags[4] = (C == 8'h00) ? 1 : 0;     // Zero Flag
                Flags[3] = (^C);                    // Paridade Flag
                Flags[2] = 0;                        // Overflow Flag (não aplicável)
                Flags[1] = 0;                        // Interrupção (não aplicável)
                Flags[0] = 0;                        // Direção (não aplicável)
            end
            
            4'hD: begin  // XNOR
                C = ~(A ^ B);
                Flags[6] = C[7];                     // Sinal Flag
                Flags[5] = 0;                        // Carry Flag (não aplicável)
                Flags[4] = (C == 8'h00) ? 1 : 0;     // Zero Flag
                Flags[3] = (^C);                    // Paridade Flag
                Flags[2] = 0;                        // Overflow Flag (não aplicável)
                Flags[1] = 0;                        // Interrupção (não aplicável)
                Flags[0] = 0;                        // Direção (não aplicável)
            end

            default: begin
                C = 8'hXX;
                Flags = 7'h7F;
            end
        endcase
    end
endmodule

//===================================================================================================================================
// MÓDULO 6: ANSWER_WRITER, RESPONSÁVEL POR PEGAR AS RESPOSTAS GERADAS PELO PROGRAMA E ESCREVÊ-LAS EM ARQUIVO BINÁRIO
//===================================================================================================================================

module answer_writer(
    input wire clock,
    input wire reset,
    input wire [7:0] data_in[0:127],    // Dados de entrada para escrever no arquivo
    input wire write_enable,      // Sinal para habilitar a escrita
    input reg  answer_size       // indica a quantidade de linhas a serem escritas
    output reg done             // Indica quando a escrita está concluída
    
);
    // Identificador do arquivo
    integer file_id;

    // Inicialização: abrir o arquivo para escrita
    initial begin
        file_id = $fopen("answer.bin", "wb"); // "wb" para escrita binária
        if (file_id == 0) begin
            $display("Erro: Não foi possível abrir o arquivo 'answer.bin'.");
            $stop;
        end
        done = 0; // Especifica que a operação ainda não foi concluída
    end

    // Sempre que houver um pulso de clock, verificar condições de escrita
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            done <= 0;  // Reiniciar estado de finalização
        end else if (write_enable) begin
            integer i
            for(i = 0; i < PR; i = i + 1) begin
                $fwrite(file_id, "%c", data_in[i]); // Escreve os dados no arquivo como binário
                $display("Dado escrito: %0h", data_in); // Mensagem para depuração
            end
        end
    end

    // Finalização: fechar o arquivo
    final begin
        $fclose(file_id); // Garante que o arquivo seja fechado corretamente
        done <= 1;        // Marca o processo como concluído
        $display("Arquivo 'answer.bin' salvo com sucesso.");
    end
endmodule

//===================================================================================================================================
//===================================================================================================================================
// MÓDULO PRINCIPAL: O GRANDIOSO, E DIVOSO, O GLAMOUROSO PROCESSADOR!!! (socorro isso tá um monstro disfuncional)
//===================================================================================================================================
//===================================================================================================================================

module processador8bits(
  input wire clock, reset,               // Sincroniza os procedimentos e reseta os parâmetro, respectivamente 
  output wire [7:0] ram_data_out,        // Dados de saída da RAM (para depuração ou uso futuro)
  input wire [7:0] from_memory,
  output wire [7:0] to_memory, address,
  output wire done                      // Indica quando o processo está concluído
);
  // Conexões entre os módulos
    reg reading_phase;        // Determina se está na fase de leitura do arquivo externo
    wire [7:0] file_data_out; // Dados lidos do arquivo
    reg [7:0] ram_address;    // Endereço da RAM
    reg ram_write;            // Sinal de escrita na RAM
    reg [7:0] ram_data_in;    // Dados a serem escritos na RAM
    wire [7:0] ram_data_out;
    reg [7:0] ram_memory [0:127]; // Memória de dados da RAM
    // Controle do módulo Answer_Writer
    reg write_enable;
    reg [7:0] data_buffer [0:127];
  //
    wire [7:0] IR, A, B, C, ALU_Result;
    wire [6:0] Flags;
    wire [1:0] Bus1_Sel, Bus2_Sel, comparacao_resultado;
    wire [3:0] ALU_Sel;
    wire PC_Load, PC_Inc, A_Load, B_Load, C_Load, IR_Load, MAR_Load, CCR_Load, write;
    wire [7:0] CCR_Result;

  // Instanciação do File Reader
    File_Reader FR_inst (
        .clock(clock),
        .reset(reset),
        .data_out(file_data_out) // Dados lidos do arquivo
    );

  // Instanciação da Memória RAM
    data_memory RAM_inst (
        .clock(clock),
        .reset(reset),
        .address(ram_address),   // Endereço da RAM
        .data_in(ram_data_in),   // Dados de entrada para a RAM
        .write(ram_write),       // Sinal de escrita na RAM
        .data_out(ram_data_out)  // Dados de saída da RAM
    );

   // Controlador para enviar os dados do File Reader para a RAM
    reg [7:0] line_counter; // Contador de linhas do arquivo
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            line_counter <= 0;
            ram_address <= 0;
            ram_write <= 0;
            reading_phase = 1;
        end else if(reading_phase) begin
            if (line_counter < 128) begin
                ram_data_in <= file_data_out; // Dados do arquivo para a RAM
                ram_address <= line_counter; // Endereço correspondente na RAM
                ram_write <= 1;              // Habilita escrita na RAM
                line_counter <= line_counter + 1; // Avança para a próxima linha
            end else begin
                ram_write <= 0; // Desabilita escrita quando o arquivo termina
                reading_phase = 0;
            end
        end
    end
endmodule
