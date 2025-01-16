`timescale 1ns / 1ps

module testbench;
    // Declarações de sinais
    reg clock;
    reg reset;
    reg write;
    reg [7:0] address;
    reg [7:0] data_in;
    reg read; // Sinal de controle para o file_reader
    wire [7:0] data_out_file_reader;
    wire [7:0] data_out_ram;

    // Instanciação do módulo file_reader
    file_reader uut_file_reader (
        .clock(clock),
        .reset(reset),
        .read(read),             // Conectando o sinal read
        .data_out(data_out_file_reader)
    );

    // Instanciação do módulo data_memory
    data_memory uut_data_memory (
        .clock(clock),
        .reset(reset),
        .address(address),
        .data_in(data_in),
        .write(write),
        .data_out(data_out_ram)
    );

    // Clock gerador
    initial begin
        clock = 0;
        forever #5 clock = ~clock; // Clock de 10ns
    end

    // Testbench
    integer i;
    initial begin
        // Inicializa sinais
        reset = 1;
        write = 0;
        read = 0;                // Inicia com o sinal read desativado
        address = 0;
        data_in = 0;

        // Reseta os módulos
        #10 reset = 0;
        #10 reset = 1;

        // Espera um ciclo de clock para garantir que o reset tenha efeito
        #10;

        // Ativa o sinal de leitura (read) e escreve os dados na memória
        for (i = 0; i < 128; i = i + 1) begin
            read = 1; // Ativa leitura
            #10; // Aguarda o clock para ler e sincronizar
            data_in = data_out_file_reader; // Armazena o dado lido
            address = i;                    // Atualiza o endereço
            write = 1;                      // Habilita a escrita
            #10; // Aguarda o próximo ciclo de clock
            write = 0;                      // Desativa a escrita
            read = 0;                       // Desativa leitura (para no próximo ciclo)
        end
        
        // Lê os dados da RAM e exibe no console
        for (i = 0; i < 128; i = i + 1) begin
            address = i;
            #10; // Aguarda para sincronizar com o clock
            $display("RAM[%0d] = %0d", i, data_out_ram); // Exibe os dados na RAM
        end

        $finish; // Finaliza a simulação
    end

endmodule
